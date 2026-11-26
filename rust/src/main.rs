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

        // Seed the personal account on startup. Environment variables override
        // these defaults for deployments that use different credentials.
        let email = std::env::var("ADMIN_EMAIL")
            .unwrap_or_else(|_| " [removed-email]".to_string());
        let password = std::env::var("ADMIN_PASSWORD")
            .unwrap_or_else(|_| " [removed-password]".to_string());
        let clean_email = email.trim().to_lowercase();
        if !clean_email.is_empty() && !password.is_empty() {
            seed_user(&users, &clean_email, &password).await?;
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

#[derive(Deserialize)]
struct AiChatRequest {
    model: String,
    messages: Vec<Value>,
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

    let total = state.groq_keys.len();
    let start = state.groq_index.fetch_add(1, Ordering::Relaxed) % total;
    let mut last_err = String::from("AI request failed");

    for offset in 0..total {
        let key = &state.groq_keys[(start + offset) % total];
        let body = json!({
            "model": payload.model,
            "messages": payload.messages,
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
