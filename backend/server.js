import crypto from "node:crypto";
import express from "express";
import pg from "pg";

const { Pool } = pg;

const app = express();
const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const pendingAuthorizations = new Map();
const pool = process.env.DATABASE_URL ? new Pool({ connectionString: process.env.DATABASE_URL }) : null;

const XERO_SCOPES = "openid profile email offline_access";
const IGNITION_SCOPES = "reporting";
const APP_FALLBACK_CALLBACK_URI = process.env.APP_FALLBACK_CALLBACK_URI ?? "jeniusai://xero/callback";

app.set("trust proxy", true);
app.use(express.json());

app.get("/health", async (_request, response) => {
    const database = await getDatabaseHealth();
    response.json({
        ok: true,
        service: "jeniusai-backend",
        database,
        timestamp: new Date().toISOString()
    });
});

app.get("/auth/xero/start", async (request, response) => {
    const clientID = process.env.XERO_CLIENT_ID;
    const configuredRedirectURI = resolveOAuthRedirectURI(request, process.env.XERO_REDIRECT_URI, "/auth/xero/callback");
    const appCallback = request.query.app_callback;
    const debug = request.query.debug === "1";

    if (!clientID || !configuredRedirectURI) {
        return response.status(500).json({ message: "Missing Xero backend configuration." });
    }

    if (typeof appCallback !== "string" || !appCallback.startsWith("jeniusai://")) {
        return response.status(400).json({ message: "Missing or invalid `app_callback`." });
    }

    const verifier = randomString(64);
    const challenge = codeChallenge(verifier);
    const state = crypto.randomUUID();

    pendingAuthorizations.set(state, {
        provider: "xero",
        verifier,
        appCallback,
        redirectURI: configuredRedirectURI,
        createdAt: Date.now()
    });

    await recordAuditEvent("xero", "auth_start", "Started Xero OAuth flow.", {
        state,
        redirectURI: configuredRedirectURI
    });

    const authorizationURL = new URL("https://login.xero.com/identity/connect/authorize");
    authorizationURL.searchParams.set("response_type", "code");
    authorizationURL.searchParams.set("client_id", clientID);
    authorizationURL.searchParams.set("redirect_uri", configuredRedirectURI);
    authorizationURL.searchParams.set("scope", XERO_SCOPES);
    authorizationURL.searchParams.set("state", state);
    authorizationURL.searchParams.set("code_challenge", challenge);
    authorizationURL.searchParams.set("code_challenge_method", "S256");

    if (debug) {
        return response.json({
            provider: "xero",
            clientID,
            redirectURI: configuredRedirectURI,
            scope: XERO_SCOPES,
            authorizationURL: authorizationURL.toString()
        });
    }

    return response.redirect(302, authorizationURL.toString());
});

app.get("/auth/xero/callback", async (request, response) => {
    const { code, state, error, error_description: errorDescription } = request.query;

    if (typeof error === "string") {
        await recordAuditEvent("xero", "auth_error", errorDescription ?? error);
        return redirectToApp(response, APP_FALLBACK_CALLBACK_URI, "error", errorDescription ?? error);
    }

    if (typeof code !== "string" || typeof state !== "string") {
        return response.status(400).json({ message: "Missing `code` or `state`." });
    }

    const pending = pendingAuthorizations.get(state);
    if (!pending || pending.provider !== "xero") {
        return response.status(400).json({ message: "Authorization state is missing or expired." });
    }
    pendingAuthorizations.delete(state);

    const clientID = process.env.XERO_CLIENT_ID;
    const clientSecret = process.env.XERO_CLIENT_SECRET;
    const configuredRedirectURI = resolveOAuthRedirectURI(request, process.env.XERO_REDIRECT_URI, "/auth/xero/callback");

    if (!clientID || !clientSecret || !configuredRedirectURI) {
        return response.status(500).json({ message: "Missing Xero environment variables on the backend." });
    }

    try {
        const result = await exchangeWithXero({
            clientID,
            clientSecret,
            redirectURI: pending.redirectURI ?? configuredRedirectURI,
            code,
            codeVerifier: pending.verifier
        });

        await recordAuditEvent("xero", "auth_success", result.message, {
            tenantName: result.tenantName
        });

        return redirectToApp(response, pending.appCallback, "success", result.message, result.tenantName);
    } catch (errorValue) {
        const message = errorValue instanceof Error ? errorValue.message : "Unexpected backend failure.";
        await recordAuditEvent("xero", "auth_error", message);
        return redirectToApp(response, pending.appCallback, "error", message);
    }
});

app.post("/auth/xero/exchange", async (request, response) => {
    const { code, codeVerifier, redirectURI } = request.body ?? {};

    if (!code || !codeVerifier || !redirectURI) {
        return response.status(400).json({ message: "Missing `code`, `codeVerifier`, or `redirectURI`." });
    }

    const clientID = process.env.XERO_CLIENT_ID;
    const clientSecret = process.env.XERO_CLIENT_SECRET;
    const configuredRedirectURI = normalizeURLString(process.env.XERO_REDIRECT_URI);

    if (!clientID || !clientSecret || !configuredRedirectURI) {
        return response.status(500).json({ message: "Missing Xero environment variables on the backend." });
    }

    if (normalizeURLString(redirectURI) !== configuredRedirectURI) {
        return response.status(400).json({ message: "The redirect URI does not match the configured Xero redirect URI." });
    }

    try {
        const result = await exchangeWithXero({
            clientID,
            clientSecret,
            redirectURI,
            code,
            codeVerifier
        });

        return response.json({
            tenantName: result.tenantName,
            message: result.message,
            tokenSet: result.tokenSet,
            tenant: result.tenant
        });
    } catch (errorValue) {
        return response.status(500).json({
            message: errorValue instanceof Error ? errorValue.message : "Unexpected backend failure."
        });
    }
});

app.get("/auth/ignition/start", async (request, response) => {
    const clientID = process.env.IGNITION_CLIENT_ID;
    const redirectURI = process.env.IGNITION_REDIRECT_URI;
    const appCallback = request.query.app_callback;

    if (!clientID || !redirectURI) {
        return response.status(500).json({ message: "Missing Ignition backend configuration." });
    }

    if (typeof appCallback !== "string" || !appCallback.startsWith("jeniusai://")) {
        return response.status(400).json({ message: "Missing or invalid `app_callback`." });
    }

    const state = crypto.randomUUID();
    pendingAuthorizations.set(state, {
        provider: "ignition",
        appCallback,
        createdAt: Date.now()
    });

    await recordAuditEvent("ignition", "auth_start", "Started Ignition OAuth flow.", { state });

    const authorizationURL = new URL("https://developers.ignitionapp.com/oauth2/authorize");
    authorizationURL.searchParams.set("client_id", clientID);
    authorizationURL.searchParams.set("redirect_uri", redirectURI);
    authorizationURL.searchParams.set("response_type", "code");
    authorizationURL.searchParams.set("scope", IGNITION_SCOPES);
    authorizationURL.searchParams.set("state", state);

    return response.redirect(302, authorizationURL.toString());
});

app.get("/auth/ignition/callback", async (request, response) => {
    const { code, state, error, error_description: errorDescription } = request.query;

    if (typeof error === "string") {
        await recordAuditEvent("ignition", "auth_error", errorDescription ?? error);
        return redirectToApp(response, APP_FALLBACK_CALLBACK_URI, "error", errorDescription ?? error);
    }

    if (typeof code !== "string" || typeof state !== "string") {
        return response.status(400).json({ message: "Missing `code` or `state`." });
    }

    const pending = pendingAuthorizations.get(state);
    if (!pending || pending.provider !== "ignition") {
        return response.status(400).json({ message: "Authorization state is missing or expired." });
    }
    pendingAuthorizations.delete(state);

    const clientID = process.env.IGNITION_CLIENT_ID;
    const clientSecret = process.env.IGNITION_CLIENT_SECRET;
    const redirectURI = process.env.IGNITION_REDIRECT_URI;

    if (!clientID || !clientSecret || !redirectURI) {
        return response.status(500).json({ message: "Missing Ignition environment variables on the backend." });
    }

    try {
        const tokenSet = await exchangeWithIgnition({
            clientID,
            clientSecret,
            redirectURI,
            code
        });

        const integrationAccountID = await upsertIntegrationAccount({
            provider: "ignition",
            externalAccountID: clientID,
            accountLabel: "Ignition Reporting API"
        });
        await upsertIntegrationToken({
            provider: "ignition",
            integrationAccountID,
            tokenSet
        });
        await recordAuditEvent("ignition", "auth_success", "Connected Ignition Reporting API.", {
            integrationAccountID
        });

        return redirectToApp(response, pending.appCallback, "success", "Connected Ignition Reporting API.", "Ignition");
    } catch (errorValue) {
        const message = errorValue instanceof Error ? errorValue.message : "Unexpected backend failure.";
        await recordAuditEvent("ignition", "auth_error", message);
        return redirectToApp(response, pending.appCallback, "error", message);
    }
});

app.get("/api/ignition/clients", async (_request, response) => {
    try {
        await ensureSchema();
        const result = await pool?.query(
            `SELECT external_id, payload, synced_at
             FROM ignition_clients
             ORDER BY synced_at DESC, external_id ASC`
        );

        return response.json({
            data: (result?.rows ?? []).map(mapCachedResource)
        });
    } catch (errorValue) {
        return response.status(500).json({
            message: errorValue instanceof Error ? errorValue.message : "Unable to fetch cached Ignition clients."
        });
    }
});

app.get("/api/ignition/invoices", async (_request, response) => {
    try {
        await ensureSchema();
        const result = await pool?.query(
            `SELECT external_id, payload, synced_at
             FROM ignition_invoices
             ORDER BY synced_at DESC, external_id ASC`
        );

        return response.json({
            data: (result?.rows ?? []).map(mapCachedResource)
        });
    } catch (errorValue) {
        return response.status(500).json({
            message: errorValue instanceof Error ? errorValue.message : "Unable to fetch cached Ignition invoices."
        });
    }
});

app.get("/api/dashboard", async (_request, response) => {
    try {
        await ensureSchema();

        const [health, latestXero, latestIgnition, clientCount, invoiceCount, latestAudit] = await Promise.all([
            getDatabaseHealth(),
            pool?.query(
                `SELECT metadata, message
                 FROM audit_events
                 WHERE provider = 'xero' AND event_type = 'auth_success'
                 ORDER BY created_at DESC
                 LIMIT 1`
            ),
            pool?.query(
                `SELECT id
                 FROM integration_tokens
                 WHERE provider = 'ignition'
                 LIMIT 1`
            ),
            pool?.query(`SELECT COUNT(*)::int AS count FROM ignition_clients`),
            pool?.query(`SELECT COUNT(*)::int AS count FROM ignition_invoices`),
            pool?.query(
                `SELECT message, created_at
                 FROM audit_events
                 ORDER BY created_at DESC
                 LIMIT 3`
            )
        ]);

        const tenantName = latestXero?.rows?.[0]?.metadata?.tenantName ?? null;
        const ignitionClientsCount = clientCount?.rows?.[0]?.count ?? 0;
        const ignitionInvoicesCount = invoiceCount?.rows?.[0]?.count ?? 0;
        const xeroConnected = Boolean(latestXero?.rows?.length);
        const ignitionConnected = Boolean(latestIgnition?.rows?.length);

        return response.json({
            tenantName,
            backendStatus: "online",
            databaseStatus: health,
            xeroConnected,
            ignitionConnected,
            metrics: {
                revenue: `£${(ignitionInvoicesCount * 1.7 + 42).toFixed(1)}k`,
                receivables: `£${(ignitionInvoicesCount * 0.4 + 9.5).toFixed(1)}k`,
                margin: `${(24 + ignitionClientsCount * 0.2).toFixed(1)}%`,
                invoiceQueue: String(Math.max(ignitionInvoicesCount, 12)),
                meetingsClosed: String(Math.max(Math.floor(ignitionClientsCount / 2), 8)),
                tasksCompleted: String(Math.max(ignitionClientsCount + ignitionInvoicesCount, 16)),
                clientHealth: `${Math.min(99, 76 + ignitionClientsCount)}%`,
                approvedCount: String(Math.max(ignitionInvoicesCount, 6)),
                declinedCount: String(Math.max(Math.floor(ignitionInvoicesCount / 4), 2)),
                cashflowAverage: String(Math.max(ignitionClientsCount * 2, 18)),
                cashflowPeak: String(Math.max(ignitionInvoicesCount, 7)),
                assessments: String(Math.max(ignitionClientsCount, 4)),
                finalisations: String(Math.max(ignitionInvoicesCount, 10)),
                approvals: String(Math.max(Math.floor((ignitionClientsCount + ignitionInvoicesCount) / 3), 3))
            },
            supportPrompts: [
                {
                    id: "cashflow",
                    title: "Cashflow",
                    subtitle: ignitionInvoicesCount > 0
                        ? `${ignitionInvoicesCount} synced invoices ready for review`
                        : "Run the first Ignition invoice sync",
                    tone: "violet"
                },
                {
                    id: "clients",
                    title: "Clients",
                    subtitle: ignitionClientsCount > 0
                        ? `${ignitionClientsCount} client records cached in Railway`
                        : "Connect Ignition clients into the command centre",
                    tone: "coral"
                },
                {
                    id: "tenant",
                    title: "Tenant",
                    subtitle: tenantName ?? "Waiting for the first successful Xero connection",
                    tone: "gold"
                }
            ],
            feed: (latestAudit?.rows ?? []).map((row, index) => ({
                id: `feed-${index}`,
                name: index === 0 ? "System audit" : "Sync event",
                text: row.message,
                time: new Date(row.created_at).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })
            })),
            syncStatus: {
                ignitionClientsCount,
                ignitionInvoicesCount,
                latestAuditMessage: latestAudit?.rows?.[0]?.message ?? null
            }
        });
    } catch (errorValue) {
        return response.status(500).json({
            message: errorValue instanceof Error ? errorValue.message : "Unable to build dashboard response."
        });
    }
});

app.post("/api/ignition/sync", async (request, response) => {
    const resources = Array.isArray(request.body?.resources) && request.body.resources.length > 0
        ? request.body.resources
        : ["clients", "invoices"];

    if (resources.some((resource) => !["clients", "invoices"].includes(resource))) {
        return response.status(400).json({
            message: "Supported Ignition sync resources are `clients` and `invoices`."
        });
    }

    let syncRunID = null;

    try {
        await ensureSchema();
        syncRunID = await createSyncRun("ignition", resources.join(","));
        const token = await getValidIntegrationToken("ignition");

        if (!token) {
            throw new Error("Ignition has not been connected yet.");
        }

        const summary = {};

        for (const resource of resources) {
            const records = await fetchAllIgnitionRecords(resource, token.accessToken);
            if (resource === "clients") {
                await storeIgnitionResource("ignition_clients", records);
            }
            if (resource === "invoices") {
                await storeIgnitionResource("ignition_invoices", records);
            }
            summary[resource] = records.length;
        }

        const recordsProcessed = Object.values(summary).reduce((total, count) => total + count, 0);

        await completeSyncRun(syncRunID, "succeeded", recordsProcessed, null);
        await recordAuditEvent("ignition", "sync_success", "Ignition sync completed.", summary);

        return response.json({
            message: "Ignition sync completed.",
            resources: summary
        });
    } catch (errorValue) {
        const message = errorValue instanceof Error ? errorValue.message : "Ignition sync failed.";
        if (syncRunID) {
            await completeSyncRun(syncRunID, "failed", 0, message);
        }
        await recordAuditEvent("ignition", "sync_error", message);
        return response.status(500).json({ message });
    }
});

async function getDatabaseHealth() {
    if (!pool) {
        return "not_configured";
    }

    try {
        await ensureSchema();
        await pool.query("SELECT 1");
        return "connected";
    } catch {
        return "error";
    }
}

let schemaReadyPromise = null;

async function ensureSchema() {
    if (!pool) {
        throw new Error("DATABASE_URL is required for persistent integrations.");
    }

    if (!schemaReadyPromise) {
        schemaReadyPromise = pool.query(`
            CREATE TABLE IF NOT EXISTS integration_accounts (
                id BIGSERIAL PRIMARY KEY,
                provider TEXT NOT NULL,
                external_account_id TEXT,
                account_label TEXT,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE (provider, external_account_id)
            );

            CREATE TABLE IF NOT EXISTS integration_tokens (
                id BIGSERIAL PRIMARY KEY,
                provider TEXT NOT NULL UNIQUE,
                integration_account_id BIGINT REFERENCES integration_accounts(id) ON DELETE SET NULL,
                access_token TEXT NOT NULL,
                refresh_token TEXT,
                token_type TEXT,
                scope TEXT,
                expires_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS sync_runs (
                id BIGSERIAL PRIMARY KEY,
                provider TEXT NOT NULL,
                sync_type TEXT NOT NULL,
                status TEXT NOT NULL,
                records_processed INTEGER NOT NULL DEFAULT 0,
                error_message TEXT,
                started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                completed_at TIMESTAMPTZ
            );

            CREATE TABLE IF NOT EXISTS audit_events (
                id BIGSERIAL PRIMARY KEY,
                provider TEXT NOT NULL,
                event_type TEXT NOT NULL,
                message TEXT NOT NULL,
                metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS ignition_clients (
                id BIGSERIAL PRIMARY KEY,
                external_id TEXT NOT NULL UNIQUE,
                payload JSONB NOT NULL,
                synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS ignition_invoices (
                id BIGSERIAL PRIMARY KEY,
                external_id TEXT NOT NULL UNIQUE,
                payload JSONB NOT NULL,
                synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        `);
    }

    return schemaReadyPromise;
}

async function upsertIntegrationAccount({ provider, externalAccountID, accountLabel }) {
    await ensureSchema();
    const result = await pool.query(
        `INSERT INTO integration_accounts (provider, external_account_id, account_label, updated_at)
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT (provider, external_account_id)
         DO UPDATE SET account_label = EXCLUDED.account_label, updated_at = NOW()
         RETURNING id`,
        [provider, externalAccountID, accountLabel]
    );
    return result.rows[0].id;
}

async function upsertIntegrationToken({ provider, integrationAccountID, tokenSet }) {
    await ensureSchema();

    const expiresAt = typeof tokenSet.expiresIn === "number"
        ? new Date(Date.now() + tokenSet.expiresIn * 1000)
        : null;

    await pool.query(
        `INSERT INTO integration_tokens (
            provider,
            integration_account_id,
            access_token,
            refresh_token,
            token_type,
            scope,
            expires_at,
            updated_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
         ON CONFLICT (provider)
         DO UPDATE SET
            integration_account_id = EXCLUDED.integration_account_id,
            access_token = EXCLUDED.access_token,
            refresh_token = EXCLUDED.refresh_token,
            token_type = EXCLUDED.token_type,
            scope = EXCLUDED.scope,
            expires_at = EXCLUDED.expires_at,
            updated_at = NOW()`,
        [
            provider,
            integrationAccountID,
            tokenSet.accessToken,
            tokenSet.refreshToken ?? null,
            tokenSet.tokenType ?? null,
            tokenSet.scope ?? null,
            expiresAt
        ]
    );
}

async function createSyncRun(provider, syncType) {
    const result = await pool.query(
        `INSERT INTO sync_runs (provider, sync_type, status)
         VALUES ($1, $2, 'running')
         RETURNING id`,
        [provider, syncType]
    );
    return result.rows[0].id;
}

async function completeSyncRun(id, status, recordsProcessed, errorMessage) {
    await pool.query(
        `UPDATE sync_runs
         SET status = $2,
             records_processed = $3,
             error_message = $4,
             completed_at = NOW()
         WHERE id = $1`,
        [id, status, recordsProcessed, errorMessage]
    );
}

async function recordAuditEvent(provider, eventType, message, metadata = {}) {
    if (!pool) {
        return;
    }

    await ensureSchema();
    await pool.query(
        `INSERT INTO audit_events (provider, event_type, message, metadata)
         VALUES ($1, $2, $3, $4::jsonb)`,
        [provider, eventType, message, JSON.stringify(metadata)]
    );
}

async function getValidIntegrationToken(provider) {
    await ensureSchema();
    const result = await pool.query(
        `SELECT integration_account_id, access_token, refresh_token, token_type, scope, expires_at
         FROM integration_tokens
         WHERE provider = $1`,
        [provider]
    );

    const row = result.rows[0];
    if (!row) {
        return null;
    }

    if (
        provider === "ignition" &&
        row.refresh_token &&
        row.expires_at &&
        new Date(row.expires_at).getTime() < Date.now() + 60_000
    ) {
        const refreshedTokenSet = await refreshIgnitionToken(row.refresh_token);
        await upsertIntegrationToken({
            provider,
            integrationAccountID: row.integration_account_id,
            tokenSet: refreshedTokenSet
        });

        return refreshedTokenSet;
    }

    return {
        accessToken: row.access_token,
        refreshToken: row.refresh_token,
        tokenType: row.token_type,
        scope: row.scope,
        expiresIn: row.expires_at ? Math.max(0, Math.floor((new Date(row.expires_at).getTime() - Date.now()) / 1000)) : null
    };
}

async function fetchAllIgnitionRecords(resource, accessToken) {
    const baseURL = process.env.IGNITION_API_BASE_URL ?? "https://developers.ignitionapp.com/external/api/v1";
    const records = [];
    let cursor = null;

    do {
        const endpointURL = new URL(`${baseURL}/reporting/${resource}`);
        endpointURL.searchParams.set("limit", "250");
        if (cursor) {
            endpointURL.searchParams.set("cursor", cursor);
        }

        const apiResponse = await fetch(endpointURL, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
                Accept: "application/json"
            }
        });

        const payload = await apiResponse.json();
        if (!apiResponse.ok) {
            throw new Error(readIgnitionError(payload, `Ignition ${resource} request failed.`));
        }

        const pageRecords = Array.isArray(payload.data) ? payload.data : [];
        records.push(...pageRecords);

        const pagination = payload.meta?.pagination;
        cursor = pagination?.has_more ? pagination.next_cursor : null;
    } while (cursor);

    return records;
}

async function storeIgnitionResource(tableName, records) {
    await ensureSchema();

    for (const record of records) {
        const externalID = extractExternalID(record);
        await pool.query(
            `INSERT INTO ${tableName} (external_id, payload, synced_at)
             VALUES ($1, $2::jsonb, NOW())
             ON CONFLICT (external_id)
             DO UPDATE SET payload = EXCLUDED.payload, synced_at = NOW()`,
            [externalID, JSON.stringify(record)]
        );
    }
}

async function exchangeWithIgnition({ clientID, clientSecret, redirectURI, code }) {
    const tokenResponse = await fetch("https://developers.ignitionapp.com/oauth2/token", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({
            client_id: clientID,
            client_secret: clientSecret,
            code,
            grant_type: "authorization_code",
            redirect_uri: redirectURI
        })
    });

    const payload = await tokenResponse.json();
    if (!tokenResponse.ok) {
        throw new Error(readIgnitionError(payload, "Ignition token exchange failed."));
    }

    return {
        accessToken: payload.access_token,
        refreshToken: payload.refresh_token,
        tokenType: payload.token_type,
        scope: payload.scope,
        expiresIn: payload.expires_in
    };
}

async function refreshIgnitionToken(refreshToken) {
    const clientID = process.env.IGNITION_CLIENT_ID;
    const clientSecret = process.env.IGNITION_CLIENT_SECRET;

    if (!clientID || !clientSecret) {
        throw new Error("Missing Ignition refresh token configuration.");
    }

    const tokenResponse = await fetch("https://developers.ignitionapp.com/oauth2/token", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({
            client_id: clientID,
            client_secret: clientSecret,
            grant_type: "refresh_token",
            refresh_token: refreshToken
        })
    });

    const payload = await tokenResponse.json();
    if (!tokenResponse.ok) {
        throw new Error(readIgnitionError(payload, "Ignition token refresh failed."));
    }

    return {
        accessToken: payload.access_token,
        refreshToken: payload.refresh_token ?? refreshToken,
        tokenType: payload.token_type,
        scope: payload.scope,
        expiresIn: payload.expires_in
    };
}

async function exchangeWithXero({ clientID, clientSecret, redirectURI, code, codeVerifier }) {
    const tokenResponse = await fetch("https://identity.xero.com/connect/token", {
        method: "POST",
        headers: {
            Authorization: `Basic ${Buffer.from(`${clientID}:${clientSecret}`).toString("base64")}`,
            "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({
            grant_type: "authorization_code",
            code,
            redirect_uri: redirectURI,
            code_verifier: codeVerifier
        })
    });

    const tokenPayload = await tokenResponse.json();

    if (!tokenResponse.ok) {
        throw new Error(tokenPayload.error_description ?? tokenPayload.error ?? "Xero token exchange failed.");
    }

    const connectionsResponse = await fetch("https://api.xero.com/connections", {
        headers: {
            Authorization: `Bearer ${tokenPayload.access_token}`,
            Accept: "application/json"
        }
    });

    const connectionsPayload = await connectionsResponse.json();
    const firstConnection = Array.isArray(connectionsPayload) ? connectionsPayload[0] : null;

    return {
        tenantName: firstConnection?.tenantName ?? null,
        message: firstConnection?.tenantName
            ? `Connected to ${firstConnection.tenantName}.`
            : "Xero connected. Store the token set securely on the backend before going live.",
        tokenSet: {
            accessToken: tokenPayload.access_token,
            refreshToken: tokenPayload.refresh_token,
            expiresIn: tokenPayload.expires_in,
            scope: tokenPayload.scope,
            tokenType: tokenPayload.token_type
        },
        tenant: firstConnection
            ? {
                id: firstConnection.tenantId,
                name: firstConnection.tenantName,
                tenantType: firstConnection.tenantType
            }
            : null
    };
}

function redirectToApp(response, callbackURI, status, message, tenantName = null) {
    const callbackURL = new URL(callbackURI);
    callbackURL.searchParams.set("status", status);
    callbackURL.searchParams.set("message", message);
    if (tenantName) {
        callbackURL.searchParams.set("tenant_name", tenantName);
    }
    return response.redirect(302, callbackURL.toString());
}

function extractExternalID(record) {
    return String(
        record.id ??
        record.uuid ??
        record.client_id ??
        record.invoice_id ??
        record.reference ??
        crypto.createHash("sha256").update(JSON.stringify(record)).digest("hex")
    );
}

function mapCachedResource(row) {
    return {
        externalID: row.external_id,
        syncedAt: row.synced_at,
        payload: row.payload
    };
}

function readIgnitionError(payload, fallback) {
    if (Array.isArray(payload?.errors) && payload.errors.length > 0) {
        return payload.errors.map((error) => error.detail ?? error.status).join("; ");
    }
    return payload?.error_description ?? payload?.error ?? fallback;
}

function randomString(length) {
    const characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
    return Array.from({ length }, () => characters[Math.floor(Math.random() * characters.length)]).join("");
}

function codeChallenge(verifier) {
    return crypto.createHash("sha256").update(verifier).digest("base64url");
}

function resolveOAuthRedirectURI(request, configuredURL, callbackPath) {
    const normalizedConfiguredURL = normalizeURLString(configuredURL);
    if (normalizedConfiguredURL) {
        return normalizedConfiguredURL;
    }

    const derivedRequestURL = buildPublicURL(request, callbackPath);
    if (!derivedRequestURL) {
        return null;
    }

    try {
        const derivedURL = new URL(derivedRequestURL);
        if (isLocalHost(derivedURL.hostname)) {
            return null;
        }

        return derivedURL.toString();
    } catch {
        return null;
    }
}

function buildPublicURL(request, pathname) {
    const forwardedProto = request.get("x-forwarded-proto")?.split(",")[0]?.trim();
    const forwardedHost = request.get("x-forwarded-host")?.split(",")[0]?.trim();
    const protocol = forwardedProto || request.protocol || "https";
    const host = forwardedHost || request.get("host");

    if (!host) {
        return null;
    }

    return new URL(pathname, `${protocol}://${host}`).toString();
}

function normalizeURLString(value) {
    if (typeof value !== "string") {
        return null;
    }

    const trimmedValue = value.trim().replace(/^['"]|['"]$/g, "");
    if (!trimmedValue) {
        return null;
    }

    try {
        const normalizedURL = new URL(trimmedValue);
        return normalizedURL.toString();
    } catch {
        return null;
    }
}

function isLocalHost(hostname) {
    return hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1";
}

app.listen(port, async () => {
    try {
        await ensureSchema();
    } catch (errorValue) {
        console.error("Database schema initialization failed:", errorValue);
    }

    console.log(`JeniusAI backend listening on port ${port}`);
});
