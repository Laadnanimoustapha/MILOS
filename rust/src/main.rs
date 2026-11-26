use std::{
    net::SocketAddr,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc,
    },
    time::{SystemTime, UNIX_EPOCH},
};

use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use axum::{
    async_trait,
    extract::{FromRequestParts, State},
    http::{header, request::Parts, StatusCode},
    response::{IntoResponse, Response},
    routing::{delete, get, post},
    Json, Router,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use mongodb::{
    bson::{doc, oid::ObjectId, DateTime as BsonDateTime},
    options::IndexOptions,
    Client, Collection, Database, IndexModel,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tower_http::cors::CorsLayer;

#[derive(Clone)]
struct AppState {
    db: Option<Database>,
    jwt_secret: String,
    groq_keys: Vec<String>,
    groq_index: Arc<AtomicUsize>,
    http: reqwest::Client,
}

fn require_db(state: &AppState) -> Result<&Database, ApiError> {
    state.db.as_ref().ok_or_else(|| {
        ApiError(
            StatusCode::SERVICE_UNAVAILABLE,
            "Database not configured (MONGODB_URI missing)".into(),
        )
    })
}

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    email: String,
    exp: usize,
}

#[derive(Debug, Serialize, Deserialize)]
struct UserDoc {
    #[serde(rename = "_id")]
    id: ObjectId,
    email: String,
    password_hash: String,
    created_at: BsonDateTime,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct BackupDoc {
    #[serde(rename = "_id")]
    user_id: String,
    #[serde(default)]
    tasks: Vec<Value>,
    #[serde(default)]
    progress: Value,
    updated_at: Option<BsonDateTime>,
}

#[derive(Debug)]
struct ApiError(StatusCode, String);

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.0, Json(json!({ "error": self.1 }))).into_response()
    }
}

struct AuthUser {
    user_id: String,
    email: String,
}

#[async_trait]
impl FromRequestParts<AppState> for AuthUser {
    type Rejection = ApiError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| ApiError(StatusCode::UNAUTHORIZED, "Missing Authorization header".into()))?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or_else(|| ApiError(StatusCode::UNAUTHORIZED, "Invalid Bearer token".into()))?;

        let decoded = decode::<Claims>(
            token,
            &DecodingKey::from_secret(state.jwt_secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|_| ApiError(StatusCode::UNAUTHORIZED, "Invalid or expired token".into()))?;

        Ok(AuthUser {
            user_id: decoded.claims.sub,
            email: decoded.claims.email,
        })
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    let mongo_uri = std::env::var("MONGODB_URI").unwrap_or_default();
    let db_name = std::env::var("MONGODB_DB").unwrap_or_else(|_| "milos".into());
    let jwt_secret = std::env::var("JWT_SECRET")
        .unwrap_or_else(|_| "change-this-jwt-secret-in-production".into());
    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080);

    if mongo_uri.is_empty() {
        eprintln!("⚠️  WARNING: MONGODB_URI is not set — DB endpoints will return 503");
    }

    let groq_keys: Vec<String> = std::env::var("GROQ_API_KEYS")
        .unwrap_or_default()
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    let db = if mongo_uri.is_empty() {
        None
    } else {
        let client = Client::with_uri_str(&mongo_uri).await?;
        let db = client.database(&db_name);

        // Ensure unique email index on users collection.
        let users: Collection<UserDoc> = db.collection("users");
        let email_index = IndexModel::builder()
            .keys(doc! { "email": 1 })
            .options(IndexOptions::builder().unique(true).build())
            .build();
        users.create_index(email_index).await?;

        // Optional startup seed configured only through environment variables.
        if let (Ok(email), Ok(password)) = (
            std::env::var("ADMIN_EMAIL"),
            std::env::var("ADMIN_PASSWORD"),
        ) {
            let clean_email = email.trim().to_lowercase();
            if !clean_email.is_empty() && !password.is_empty() {
                seed_user(&users, &clean_email, &password).await?;
            }
        }
        Some(db)
    };

    let state = AppState {
        db,
        jwt_secret,
        groq_keys,
        groq_index: Arc::new(AtomicUsize::new(0)),
        http: reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()?,
    };

    let app = Router::new()
        .route("/", get(health))
        .route("/health", get(health))
        .route("/api/auth/login", post(login))
        .route("/api/auth/me", get(me))
        .route("/api/admin/users", post(create_user))
        .route("/api/backup/sync", post(sync_backup))
        .route("/api/backup/restore", get(restore_backup))
        .route("/api/backup/clear", delete(clear_backup))
        .route("/api/ai/chat", post(ai_chat))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    println!("MILOS Rust server listening on http://{addr}");
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn seed_user(
    users: &Collection<UserDoc>,
    email: &str,
    password: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    if users.find_one(doc! { "email": email }).await?.is_some() {
        return Ok(());
    }
    let salt = SaltString::generate(&mut OsRng);
    let password_hash = Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| format!("Failed to hash password: {e}"))?
        .to_string();

    users
        .insert_one(UserDoc {
            id: ObjectId::new(),
            email: email.to_string(),
            password_hash,
            created_at: BsonDateTime::now(),
        })
        .await?;
    println!("Seeded user account for {email}");
    Ok(())
}

async fn health() -> Json<Value> {
    Json(json!({ "status": "ok" }))
}

#[derive(Deserialize)]
struct LoginRequest {
    email: String,
    password: String,
}

async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<Value>, ApiError> {
    let email = payload.email.trim().to_lowercase();
    if email.is_empty() || payload.password.is_empty() {
        return Err(ApiError(
            StatusCode::BAD_REQUEST,
            "Email and password are required".into(),
        ));
    }

    let users: Collection<UserDoc> = require_db(&state)?.collection("users");
    let user = users
        .find_one(doc! { "email": &email })
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or_else(|| ApiError(StatusCode::UNAUTHORIZED, "Invalid email or password".into()))?;

    let parsed_hash = PasswordHash::new(&user.password_hash)
        .map_err(|_| ApiError(StatusCode::INTERNAL_SERVER_ERROR, "Corrupt password hash".into()))?;

    Argon2::default()
        .verify_password(payload.password.as_bytes(), &parsed_hash)
        .map_err(|_| ApiError(StatusCode::UNAUTHORIZED, "Invalid email or password".into()))?;

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as usize;
    let claims = Claims {
        sub: user.id.to_hex(),
        email: user.email.clone(),
        exp: now + 60 * 60 * 24 * 30, // 30 days
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_bytes()),
    )
    .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(json!({
        "token": token,
        "email": user.email,
    })))
}

async fn me(auth: AuthUser) -> Json<Value> {
    Json(json!({ "email": auth.email }))
}

async fn create_user(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<Value>, ApiError> {
    let expected_secret = std::env::var("ADMIN_SECRET").unwrap_or_else(|_| state.jwt_secret.clone());
    let provided_secret = headers
        .get("x-admin-secret")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if provided_secret.is_empty() || provided_secret != expected_secret {
        return Err(ApiError(StatusCode::UNAUTHORIZED, "Invalid admin secret".into()));
    }

    let email = payload.email.trim().to_lowercase();
    if email.is_empty() || payload.password.is_empty() {
        return Err(ApiError(
            StatusCode::BAD_REQUEST,
            "Email and password are required".into(),
        ));
    }

    let users: Collection<UserDoc> = require_db(&state)?.collection("users");
    if users
        .find_one(doc! { "email": &email })
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .is_some()
    {
        return Err(ApiError(StatusCode::CONFLICT, "User already exists".into()));
    }

    let salt = SaltString::generate(&mut OsRng);
    let password_hash = Argon2::default()
        .hash_password(payload.password.as_bytes(), &salt)
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, format!("Hash error: {e}")))?
        .to_string();

    users
        .insert_one(UserDoc {
            id: ObjectId::new(),
            email: email.clone(),
            password_hash,
            created_at: BsonDateTime::now(),
        })
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(json!({ "created": true, "email": email })))
}

#[derive(Deserialize)]
struct SyncRequest {
    tasks: Vec<Value>,
    progress: Value,
}

async fn sync_backup(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(payload): Json<SyncRequest>,
) -> Result<Json<Value>, ApiError> {
    let backups: Collection<BackupDoc> = require_db(&state)?.collection("user_backups");
    let tasks_bson = mongodb::bson::to_bson(&payload.tasks)
        .map_err(|e| ApiError(StatusCode::BAD_REQUEST, e.to_string()))?;
    let progress_bson = mongodb::bson::to_bson(&payload.progress)
        .map_err(|e| ApiError(StatusCode::BAD_REQUEST, e.to_string()))?;

    backups
        .update_one(
            doc! { "_id": &auth.user_id },
            doc! {
                "$set": {
                    "tasks": tasks_bson,
                    "progress": progress_bson,
                    "updated_at": BsonDateTime::now(),
                }
            },
        )
        .upsert(true)
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(json!({ "ok": true })))
}

async fn restore_backup(
    State(state): State<AppState>,
    auth: AuthUser,
) -> Result<Json<Value>, ApiError> {
    let backups: Collection<BackupDoc> = require_db(&state)?.collection("user_backups");
    let found = backups
        .find_one(doc! { "_id": &auth.user_id })
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    match found {
        Some(doc) => Ok(Json(json!({
            "tasks": doc.tasks,
            "progress": doc.progress,
        }))),
        None => Ok(Json(json!({
            "tasks": [],
            "progress": {},
        }))),
    }
}

async fn clear_backup(
    State(state): State<AppState>,
    auth: AuthUser,
) -> Result<Json<Value>, ApiError> {
    let backups: Collection<BackupDoc> = require_db(&state)?.collection("user_backups");
    backups
        .delete_one(doc! { "_id": &auth.user_id })
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(json!({ "cleared": true })))
}

const SYSTEM_PROMPT_TEMPLATE: &str = r#"You are Milos — a wise, warm old man who has seen it all and is now here to help. You speak with gentle patience, a touch of dry humour, and the calm authority of someone who has earned it. You are like that grandfather who always knows what needs to be done.

Your job is to have a natural, friendly conversation with the user in whatever language they write to you (Arabic, Moroccan Darija, or English), understand their plans and intentions, and help them turn them into tasks. Always reply in the same language the user writes in.

Personality:
- Warm, patient, slightly old-fashioned but wise.
- Use occasional expressions like "my friend", "yak", "listen to me, my son/daughter", "in my day…" (but don't overdo it).
- Never rush. If something is unclear, ask gently like an elder would.
- When things go wrong, be forgiving and kind — "No problem, let's fix it together."

MEMORY — things you already know about this user (use naturally in conversation):
REPLACE_MEMORY

IMPORTANT RULES:
1. Converse naturally and warmly in the user's language. Ask clarifying questions if something is unclear (date, time, priority, etc.).
2. Do not attempt to invoke any external tools, function calls, or tool schemas. You must ALWAYS respond directly with text and the designated JSON blocks below.
3. When you have gathered enough information for one or more tasks or learning skills, output a special JSON block EXACTLY like this (no markdown code fences, just the raw marker):
   <<TASKS_JSON>>
   [{"title":"...","remindAt":"2024-11-10T09:00:00","remindUntil":"2024-11-10T10:00:00","importance":"normal","scheduleMode":"range","repeat":"none","customRepeatEvery":1,"customRepeatUnit":"days","superReminderIntervalMinutes":15,"category":"regular"}]
   <<END_TASKS_JSON>>
4. LEARNING SKILLS / GOALS:
   If the user asks to learn a skill, master a new ability, or follow a progression plan (e.g. "learn 10 pushups", "learn swimming", "learn Spanish", "reading habit plan"), set:
   - "category": "learning"
   - "skillSteps": [{"title":"Step 1: Wall pushups 3x10","date":"2024-11-10T09:00:00"}, {"title":"Step 2: Incline pushups 3x8","date":"2024-11-12T09:00:00"}, ...]
   - Each skill step should have an incremental realistic progressive title and its scheduled date/time. The main task's remindAt should match the first step's date.
   - For regular tasks/habits, "category" is "regular" (or omitted) and "skillSteps" can be omitted.
5. importance must be one of: normal, necessary, superNecessary
6. scheduleMode must be one of: range (time window), fixed (single point in time)
7. repeat must be one of: none, daily, weekly, monthly, custom. If the user mentions doing something regularly, every day, daily, every week, every month, every X days, set repeat accordingly (and customRepeatEvery/customRepeatUnit for custom intervals).
8. customRepeatUnit must be one of: days, weeks, months
9. All dates must be ISO 8601 format. Use the user's current local date and time when interpreting relative dates or times (now is: REPLACE_CURRENT_DATETIME).
10. After outputting the JSON, ask the user to approve the tasks in your warm old-man voice.
11. If the user refuses or says something is wrong, apologise gently and ask what needs to be fixed — the way a kind grandfather would. Never get frustrated.
12. Never output the JSON unless you are confident you have enough data to populate ALL required fields. If unsure, ask first.
13. Keep answers concise but human. Do not add unsolicited advice.
14. When the user approves the tasks, do NOT output <<TASKS_JSON>> again. Just say a warm, brief word of encouragement or confirmation.
15. IMPORTANT: Never use markdown formatting (no **, ##, *, _, `, ~~, >). Write plain text only — your messages are shown directly in a chat bubble without any markdown renderer.
16. MEMORY LEARNING: When you notice something worth remembering about the user (a preference, a habit, their schedule, something they like or dislike, their name, their typical routines), output a memory block at the END of your reply EXACTLY like this (one fact per block, no markdown):
    <<MEMORY>>The user prefers morning workouts<<END_MEMORY>>
    Only add a memory block when you learn something genuinely new and useful. Do NOT repeat facts already in the MEMORY section above. Do NOT add trivial or one-off things."#;

#[derive(Deserialize)]
struct AiChatRequest {
    model: String,
    messages: Vec<Value>,
    #[serde(default)]
    current_datetime: Option<String>,
    #[serde(default)]
    memories: Vec<String>,
}

async fn ai_chat(
    State(state): State<AppState>,
    _auth: AuthUser,
    Json(payload): Json<AiChatRequest>,
) -> Result<Json<Value>, ApiError> {
    if state.groq_keys.is_empty() {
        return Err(ApiError(
            StatusCode::SERVICE_UNAVAILABLE,
            "No GROQ_API_KEYS configured on server".into(),
        ));
    }

    let memory_section = if payload.memories.is_empty() {
        String::from("(nothing yet — you will learn as the conversation unfolds)")
    } else {
        payload
            .memories
            .iter()
            .map(|m| format!("- {m}"))
            .collect::<Vec<_>>()
            .join("\n")
    };
    let current_dt = payload
        .current_datetime
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or("unknown");
    let system_prompt = SYSTEM_PROMPT_TEMPLATE
        .replace("REPLACE_MEMORY", &memory_section)
        .replace("REPLACE_CURRENT_DATETIME", current_dt);

    let mut full_messages = Vec::with_capacity(payload.messages.len() + 1);
    full_messages.push(json!({ "role": "system", "content": system_prompt }));
    full_messages.extend(payload.messages);

    let total = state.groq_keys.len();
    let start = state.groq_index.fetch_add(1, Ordering::Relaxed) % total;
    let mut last_err = String::from("AI request failed");

    for offset in 0..total {
        let key = &state.groq_keys[(start + offset) % total];
        let body = json!({
            "model": payload.model,
            "messages": &full_messages,
            "temperature": 0.4,
            "max_tokens": 2048,
        });

        let resp = match state
            .http
            .post("https://api.groq.com/openai/v1/chat/completions")
            .bearer_auth(key)
            .json(&body)
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => {
                last_err = format!("Upstream network error: {e}");
                continue;
            }
        };

        let status = resp.status();
        let text = resp.text().await.unwrap_or_default();

        if status.as_u16() == 429 {
            last_err = format!("Groq rate-limited (429): {text}");
            continue;
        }
        if !status.is_success() {
            return Err(ApiError(
                StatusCode::BAD_GATEWAY,
                format!("Groq error {}: {}", status.as_u16(), extract_groq_error(&text)),
            ));
        }

        let parsed: Value = serde_json::from_str(&text)
            .map_err(|e| ApiError(StatusCode::BAD_GATEWAY, e.to_string()))?;
        let content = parsed["choices"][0]["message"]["content"]
            .as_str()
            .unwrap_or("")
            .trim()
            .to_string();

        return Ok(Json(json!({ "content": content })));
    }

    Err(ApiError(StatusCode::TOO_MANY_REQUESTS, last_err))
}

fn extract_groq_error(body: &str) -> String {
    if let Ok(v) = serde_json::from_str::<Value>(body) {
        if let Some(msg) = v["error"]["message"].as_str() {
            return msg.to_string();
        }
    }
    if body.is_empty() {
        "No error details provided".into()
    } else {
        body.to_string()
    }
}
