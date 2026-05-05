# Backend Architecture

## Decisions

### Backend framework

- **Node.js + Express on Railway**
- Reason:
  - minimal setup for a first deployment
  - fast iteration for OAuth callbacks and small API endpoints
  - native fit for Railway's Node deployment flow

This is the **phase 1 backend**, not the final platform boundary. If the product grows into heavier workflow orchestration, background jobs, or more complex data models, the backend can later move to a more opinionated structure without changing the mobile contract.

### API layer

- **REST**, not GraphQL
- Reason:
  - the current iOS app needs a small, explicit contract
  - easier to debug in Railway and Xero integration work
  - lower complexity while the domain model is still forming

Initial internal API endpoints:

- `GET /health`
- `POST /auth/xero/exchange`

Planned next endpoints:

- `GET /api/dashboard`
- `GET /api/workflows`
- `GET /api/folders`
- `GET /api/people`

### Auth system

Two auth layers are required and should stay separate.

#### 1. Xero OAuth

- Purpose: connect a Xero organisation to JeniusAI
- Flow:
  1. iOS app starts PKCE sign-in with Xero
  2. Xero redirects back to `jeniusai://xero/callback`
  3. iOS app sends the auth code and PKCE verifier to Railway
  4. Railway exchanges the code with Xero using the client secret
  5. Railway stores Xero tokens securely server-side

This keeps the Xero client secret out of the iOS app.

#### 2. Internal user auth

- Purpose: staff logins, roles, permissions, audit boundaries
- Decision for now:
  - **do not build custom auth in phase 1**
  - phase 1 stays focused on product shell + integration setup

Recommended phase 2 approach:

- Railway backend issues app sessions
- staff auth via:
  - Clerk, Auth0, or Supabase Auth
  - or Google/Microsoft SSO if the business workflow requires managed staff access

### Roles and permissions

Not implemented yet, but the expected model is:

- `admin`
- `manager`
- `staff`
- `client`

These should be enforced on the backend, not in the app UI.

## Deployment shape

- Railway service root: `backend`
- Public backend domain:
  - `https://<service>.up.railway.app`
- App environment variable:
  - `RAILWAY_BASE_URL=https://<service>.up.railway.app`

## Required environment variables

Backend:

- `XERO_CLIENT_ID`
- `XERO_CLIENT_SECRET`
- `XERO_REDIRECT_URI=jeniusai://xero/callback`

App:

- `XERO_CLIENT_ID`
- `XERO_REDIRECT_URI=jeniusai://xero/callback`
- `RAILWAY_BASE_URL=https://<service>.up.railway.app`

## Immediate next steps

1. Deploy the backend service from the `backend` folder in Railway.
2. Add the three Xero backend environment variables.
3. Add `jeniusai://xero/callback` in Xero Developer.
4. Point the iOS app at the Railway public domain.
5. Replace in-memory/sample data with API-backed dashboard and workflow endpoints.
