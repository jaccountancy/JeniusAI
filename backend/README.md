# JeniusAI Backend

Railway service for the Xero token exchange flow used by the iOS app.

## Endpoints

- `GET /health`
- `GET /auth/xero/start`
- `GET /auth/xero/callback`
- `POST /auth/xero/exchange`

## Required environment variables

- `XERO_CLIENT_ID`
- `XERO_CLIENT_SECRET`
- `XERO_REDIRECT_URI`
- `APP_FALLBACK_CALLBACK_URI`

## Railway setup

1. Create a new service from this GitHub repo.
2. Set the service root directory to `backend`.
3. Generate a public domain.
4. Add the required environment variables.

## Structure decisions

- Backend framework: Node.js + Express
- API style: REST
- Xero auth: OAuth handled by Railway token exchange
- Internal staff auth: deferred to phase 2

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the current backend shape and auth boundaries.

## App setup

Point the iOS app to the generated public domain:

- `RAILWAY_BASE_URL=https://<your-service>.up.railway.app`

Xero should redirect to the Railway backend:

- `https://<your-service>.up.railway.app/auth/xero/callback`

The backend then deep-links back into the app:

- `jeniusai://xero/callback`
