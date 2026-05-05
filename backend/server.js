import express from "express";

const app = express();
const port = Number.parseInt(process.env.PORT ?? "3000", 10);

app.use(express.json());

app.get("/health", (_request, response) => {
    response.json({
        ok: true,
        service: "jeniusai-backend",
        timestamp: new Date().toISOString()
    });
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
            return response.status(tokenResponse.status).json({
                message: tokenPayload.error_description ?? tokenPayload.error ?? "Xero token exchange failed."
            });
        }

        const connectionsResponse = await fetch("https://api.xero.com/connections", {
            headers: {
                Authorization: `Bearer ${tokenPayload.access_token}`,
                Accept: "application/json"
            }
        });

        const connectionsPayload = await connectionsResponse.json();
        const firstConnection = Array.isArray(connectionsPayload) ? connectionsPayload[0] : null;

        return response.json({
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
        });
    } catch (error) {
        return response.status(500).json({
            message: error instanceof Error ? error.message : "Unexpected backend failure."
        });
    }
});

app.listen(port, () => {
    console.log(`JeniusAI backend listening on port ${port}`);
});
