import express from "express";
import crypto from "node:crypto";

const app = express();
const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const pendingAuthorizations = new Map();

app.use(express.json());

app.get("/health", (_request, response) => {
    response.json({
        ok: true,
        service: "jeniusai-backend",
        timestamp: new Date().toISOString()
    });
});

app.get("/auth/xero/start", (request, response) => {
    const clientID = process.env.XERO_CLIENT_ID;
    const configuredRedirectURI = process.env.XERO_REDIRECT_URI;
    const appCallback = request.query.app_callback;

    if (!clientID || !configuredRedirectURI) {
        return response.status(500).json({
            message: "Missing Xero backend configuration."
        });
    }

    if (typeof appCallback !== "string" || !appCallback.startsWith("jeniusai://")) {
        return response.status(400).json({
            message: "Missing or invalid `app_callback`."
        });
    }

    const verifier = randomString(64);
    const challenge = codeChallenge(verifier);
    const state = crypto.randomUUID();

    pendingAuthorizations.set(state, {
        verifier,
        appCallback,
        createdAt: Date.now()
    });

    var authorizationURL = new URL("https://login.xero.com/identity/connect/authorize");
    authorizationURL.searchParams.set("response_type", "code");
    authorizationURL.searchParams.set("client_id", clientID);
    authorizationURL.searchParams.set("redirect_uri", configuredRedirectURI);
    authorizationURL.searchParams.set("scope", "openid profile email offline_access accounting.transactions");
    authorizationURL.searchParams.set("state", state);
    authorizationURL.searchParams.set("code_challenge", challenge);
    authorizationURL.searchParams.set("code_challenge_method", "S256");

    return response.redirect(302, authorizationURL.toString());
});

app.get("/auth/xero/callback", async (request, response) => {
    const { code, state, error, error_description: errorDescription } = request.query;

    if (typeof error === "string") {
        return redirectToApp(
            response,
            process.env.APP_FALLBACK_CALLBACK_URI ?? "jeniusai://xero/callback",
            "error",
            errorDescription ?? error
        );
    }

    if (typeof code !== "string" || typeof state !== "string") {
        return response.status(400).json({
            message: "Missing `code` or `state`."
        });
    }

    const pending = pendingAuthorizations.get(state);
    if (!pending) {
        return response.status(400).json({
            message: "Authorization state is missing or expired."
        });
    }
    pendingAuthorizations.delete(state);

    const clientID = process.env.XERO_CLIENT_ID;
    const clientSecret = process.env.XERO_CLIENT_SECRET;
    const configuredRedirectURI = process.env.XERO_REDIRECT_URI;

    if (!clientID || !clientSecret || !configuredRedirectURI) {
        return response.status(500).json({
            message: "Missing Xero environment variables on the backend."
        });
    }

    try {
        const result = await exchangeWithXero({
            clientID,
            clientSecret,
            redirectURI: configuredRedirectURI,
            code,
            codeVerifier: pending.verifier
        });

        return redirectToApp(
            response,
            pending.appCallback,
            "success",
            result.message,
            result.tenantName
        );
    } catch (errorValue) {
        const message = errorValue instanceof Error ? errorValue.message : "Unexpected backend failure."
        return redirectToApp(response, pending.appCallback, "error", message);
    }
});

app.post("/auth/xero/exchange", async (request, response) => {
    const { code, codeVerifier, redirectURI } = request.body ?? {};

    if (!code || !codeVerifier || !redirectURI) {
        return response.status(400).json({
            message: "Missing `code`, `codeVerifier`, or `redirectURI`."
        });
    }

    const clientID = process.env.XERO_CLIENT_ID;
    const clientSecret = process.env.XERO_CLIENT_SECRET;
    const configuredRedirectURI = process.env.XERO_REDIRECT_URI;

    if (!clientID || !clientSecret || !configuredRedirectURI) {
        return response.status(500).json({
            message: "Missing Xero environment variables on the backend."
        });
    }

    if (redirectURI !== configuredRedirectURI) {
        return response.status(400).json({
            message: "The redirect URI does not match the configured Xero redirect URI."
        });
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
    } catch (error) {
        return response.status(500).json({
            message: error instanceof Error ? error.message : "Unexpected backend failure."
        });
    }
});

function redirectToApp(response, callbackURI, status, message, tenantName = null) {
    const callbackURL = new URL(callbackURI);
    callbackURL.searchParams.set("status", status);
    callbackURL.searchParams.set("message", message);
    if (tenantName) {
        callbackURL.searchParams.set("tenant_name", tenantName);
    }
    return response.redirect(302, callbackURL.toString());
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

function randomString(length) {
    const characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
    return Array.from({ length }, () => characters[Math.floor(Math.random() * characters.length)]).join("");
}

function codeChallenge(verifier) {
    return crypto.createHash("sha256").update(verifier).digest("base64url");
}

app.listen(port, () => {
    console.log(`JeniusAI backend listening on port ${port}`);
});
