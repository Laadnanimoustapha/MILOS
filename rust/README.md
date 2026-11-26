# MILOS Rust Backend

Axum + MongoDB backend handling authentication, task/progress cloud backup, and Groq AI chat proxying.

## Environment Variables (`.env`)

See `.env.example`.

- `MONGODB_URI` — MongoDB connection string (already present in `.env`)
- `MONGODB_DB` — Database name (default: `milos`)
- `PORT` — HTTP port (default: `8080`)
- `JWT_SECRET` — Secret used to sign 30-day JWT tokens
- `GROQ_API_KEYS` — Comma-separated Groq API keys used for `/api/ai/chat`
- `ADMIN_EMAIL` / `ADMIN_PASSWORD` — Optional initial user seeded on startup into `users` collection (since the app has no signup screen)

## Endpoints

- `GET /health` — Health check
- `POST /api/auth/login` — `{ email, password }` → `{ token, email }`
- `GET /api/auth/me` — Bearer token check
- `POST /api/backup/sync` — Upserts `{ tasks, progress }` in MongoDB `user_backups`
- `GET /api/backup/restore` — Returns `{ tasks, progress }` from MongoDB `user_backups`
- `DELETE /api/backup/clear` — Deletes user's backup from MongoDB `user_backups`
- `POST /api/ai/chat` — `{ model, messages }` → `{ content }` (proxied to Groq)

## Run

```bash
cargo run --release
```

## Create a user

Install the small Python admin dependencies:

```bash
python -m pip install pymongo argon2-cffi
python scripts/create_user.py user@example.com
```

The script reads `MONGODB_URI` and optionally `MONGODB_DB` from `rust/.env`,
prompts for the password without echoing it, normalizes the email to lowercase,
stores an Argon2 hash, and rejects duplicate emails.
