use std::{
    collections::HashMap,
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
    extract::{FromRequestParts, Path, Query, State},
    http::{header, request::Parts, StatusCode},
    response::{IntoResponse, Response},
    routing::{delete, get, post, put},
    Json, Router,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use mongodb::{
    bson::{doc, oid::ObjectId, DateTime as BsonDateTime, Document},
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
    nvidia_keys: Vec<String>,
    nvidia_index: Arc<AtomicUsize>,
    gemini_keys: Vec<String>,
    gemini_index: Arc<AtomicUsize>,
    openrouter_keys: Vec<String>,
    openrouter_index: Arc<AtomicUsize>,
    http: reqwest::Client,
}

struct ProviderSpec<'a> {
    id: &'a str,
    chat_url: &'a str,
    models_url: &'a str,
    env_name: &'a str,
    keys: &'a [String],
    index: &'a AtomicUsize,
    stream: bool,
}

fn provider_spec<'a>(state: &'a AppState, provider: &str) -> ProviderSpec<'a> {
    match provider.trim().to_lowercase().as_str() {
        "nvidia" => ProviderSpec {
            id: "nvidia",
            chat_url: "https://integrate.api.nvidia.com/v1/chat/completions",
            models_url: "https://integrate.api.nvidia.com/v1/models",
            env_name: "NVIDIA_API_KEYS",
            keys: &state.nvidia_keys,
            index: &state.nvidia_index,
            stream: true,
        },
        "gemini" => ProviderSpec {
            id: "gemini",
            chat_url: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            models_url: "https://generativelanguage.googleapis.com/v1beta/openai/models",
            env_name: "GEMINI_API_KEYS",
            keys: &state.gemini_keys,
            index: &state.gemini_index,
            stream: false,
        },
        "openrouter" => ProviderSpec {
            id: "openrouter",
            chat_url: "https://openrouter.ai/api/v1/chat/completions",
            models_url: "https://openrouter.ai/api/v1/models",
            env_name: "OPENROUTER_API_KEYS",
            keys: &state.openrouter_keys,
            index: &state.openrouter_index,
            stream: false,
        },
        _ => ProviderSpec {
            id: "groq",
            chat_url: "https://api.groq.com/openai/v1/chat/completions",
            models_url: "https://api.groq.com/openai/v1/models",
            env_name: "GROQ_API_KEYS",
            keys: &state.groq_keys,
            index: &state.groq_index,
            stream: false,
        },
    }
}

fn build_provider_post(
    state: &AppState,
    spec: &ProviderSpec<'_>,
    key: &str,
    body: &Value,
) -> reqwest::RequestBuilder {
    let req = state.http.post(spec.chat_url).bearer_auth(key).json(body);
    if spec.id == "openrouter" {
        req.header(
            "HTTP-Referer",
            "https://milos-mustapha-laadnanis-projects.vercel.app",
        )
        .header("X-Title", "MILOS")
    } else {
        req
    }
}

fn parse_keys_env(primary: &str, fallback: &str) -> Vec<String> {
    let raw = std::env::var(primary)
        .ok()
        .filter(|s| !s.trim().is_empty())
        .or_else(|| std::env::var(fallback).ok())
        .unwrap_or_default();
    raw.split(',')
        .map(|s| s.trim().trim_matches(|c| c == '"' || c == '\'').trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
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

fn default_true() -> bool {
    true
}

fn default_provider() -> String {
    "groq".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AiModelEntry {
    id: String,
    name: String,
    #[serde(default = "default_provider")]
    provider: String,
    #[serde(default = "default_true")]
    enabled: bool,
    #[serde(default)]
    icon: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AiConfigDoc {
    #[serde(rename = "_id")]
    id: String,
    version: String,
    default_model: String,
    models: Vec<AiModelEntry>,
    updated_at: Option<BsonDateTime>,
}

#[derive(Debug, Serialize, Deserialize)]
struct UsageLogDoc {
    user_email: String,
    model: String,
    #[serde(default = "default_provider")]
    provider: String,
    prompt_tokens: u64,
    completion_tokens: u64,
    total_tokens: u64,
    created_at: BsonDateTime,
}

fn default_ai_config() -> AiConfigDoc {
    AiConfigDoc {
        id: "models".into(),
        version: "v1-default".into(),
        default_model: "openai/gpt-oss-20b".into(),
        models: vec![
            AiModelEntry { id: "openai/gpt-oss-20b".into(), name: "GPT-OSS 20B (fast)".into(), provider: "groq".into(), enabled: true, icon: String::new() },
            AiModelEntry { id: "openai/gpt-oss-120b".into(), name: "GPT-OSS 120B".into(), provider: "groq".into(), enabled: true, icon: String::new() },
            AiModelEntry { id: "qwen/qwen3.8-27b".into(), name: "Qwen 3.8 27B".into(), provider: "groq".into(), enabled: true, icon: String::new() },
            AiModelEntry { id: "allam-2-7b".into(), name: "ALLaM 2 7B (Arabic)".into(), provider: "groq".into(), enabled: true, icon: String::new() },
        ],
        updated_at: None,
    }
}

fn require_admin(state: &AppState, headers: &axum::http::HeaderMap) -> Result<(), ApiError> {
    let expected = std::env::var("ADMIN_SECRET").unwrap_or_else(|_| state.jwt_secret.clone());
    let provided = headers
        .get("x-admin-secret")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if provided.is_empty() || provided != expected {
        return Err(ApiError(StatusCode::UNAUTHORIZED, "Invalid admin secret".into()));
    }
    Ok(())
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

    let groq_keys = parse_keys_env("GROQ_API_KEYS", "GROQ_API_KEY");
    let nvidia_keys = parse_keys_env("NVIDIA_API_KEYS", "NVIDIA_API_KEY");
    let gemini_keys = parse_keys_env("GEMINI_API_KEYS", "GEMINI_API_KEY");
    let openrouter_keys = parse_keys_env("OPENROUTER_API_KEYS", "OPENROUTER_API_KEY");

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
        nvidia_keys,
        nvidia_index: Arc::new(AtomicUsize::new(0)),
        gemini_keys,
        gemini_index: Arc::new(AtomicUsize::new(0)),
        openrouter_keys,
        openrouter_index: Arc::new(AtomicUsize::new(0)),
        http: reqwest::Client::builder()
            .connect_timeout(std::time::Duration::from_secs(12))
            .timeout(std::time::Duration::from_secs(55))
            .pool_max_idle_per_host(0)
            .http1_only()
            .build()?,
    };

    let app = Router::new()
        .route("/", get(health))
        .route("/health", get(health))
        .route("/api/auth/login", post(login))
        .route("/api/auth/me", get(me))
        .route("/api/admin/users", get(list_users).post(create_user))
        .route("/api/admin/users/:id", delete(delete_user))
        .route("/api/admin/db", get(admin_db))
        .route("/api/admin/usage", get(admin_usage))
        .route("/api/admin/models", get(admin_get_models).put(admin_save_models))
        .route("/api/admin/groq-models", get(admin_groq_models))
        .route("/api/admin/nvidia-models", get(admin_nvidia_models))
        .route("/api/admin/gemini-models", get(admin_gemini_models))
        .route("/api/admin/openrouter-models", get(admin_openrouter_models))
        .route("/api/admin/provider-models/:provider", get(admin_provider_models))
        .route("/api/admin/test-model", post(admin_test_model))
        .route("/api/backup/sync", post(sync_backup))
        .route("/api/backup/restore", get(restore_backup))
        .route("/api/backup/clear", delete(clear_backup))
        .route("/api/ai/models", get(get_ai_models))
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
    require_admin(&state, &headers)?;

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

async fn list_users(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    require_admin(&state, &headers)?;
    let users: Collection<UserDoc> = require_db(&state)?.collection("users");
    let mut cursor = users
        .find(doc! {})
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let mut list = Vec::new();
    while cursor
        .advance()
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    {
        let u = cursor
            .deserialize_current()
            .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        list.push(json!({
            "id": u.id.to_hex(),
            "email": u.email,
            "created_at_ms": u.created_at.timestamp_millis(),
        }));
    }
    Ok(Json(json!({ "users": list })))
}

async fn delete_user(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<Value>, ApiError> {
    require_admin(&state, &headers)?;
    let oid = ObjectId::parse_str(&id)
        .map_err(|_| ApiError(StatusCode::BAD_REQUEST, "Invalid user id".into()))?;
    let users: Collection<UserDoc> = require_db(&state)?.collection("users");
    let res = users
        .delete_one(doc! { "_id": oid })
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    Ok(Json(json!({ "deleted": res.deleted_count > 0 })))
}

async fn admin_db(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    require_admin(&state, &headers)?;
    let db = require_db(&state)?;
    let names = db
        .list_collection_names()
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let mut collections = serde_json::Map::new();
    for name in names {
        let coll: Collection<Document> = db.collection(&name);
        let mut cursor = coll
            .find(doc! {})
            .await
            .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        let mut docs = Vec::new();
        while cursor
            .advance()
            .await
            .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        {
            let mut d = cursor
                .deserialize_current()
                .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
            if name == "users" && d.contains_key("password_hash") {
                d.insert("password_hash", "[redacted]");
            }
            let val = serde_json::to_value(&d).unwrap_or(Value::Null);
            docs.push(val);
        }
        collections.insert(name, Value::Array(docs));
    }
    Ok(Json(json!({ "collections": collections })))
}

async fn admin_usage(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    require_admin(&state, &headers)?;
    let db = require_db(&state)?;

    let users_count = db
        .collection::<Document>("users")
        .count_documents(doc! {})
        .await
        .unwrap_or(0);
    let backups_count = db
        .collection::<Document>("user_backups")
        .count_documents(doc! {})
        .await
        .unwrap_or(0);

    let logs_coll: Collection<UsageLogDoc> = db.collection("usage_logs");
    let mut cursor = logs_coll
        .find(doc! {})
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let mut total_requests: u64 = 0;
    let mut total_tokens: u64 = 0;
    let mut prompt_tokens: u64 = 0;
    let mut completion_tokens: u64 = 0;
    let mut by_model: HashMap<String, (u64, u64)> = HashMap::new();
    let mut by_user: HashMap<String, (u64, u64)> = HashMap::new();
    let mut all_logs = Vec::new();

    while cursor
        .advance()
        .await
        .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    {
        if let Ok(log) = cursor.deserialize_current() {
            total_requests += 1;
            total_tokens += log.total_tokens;
            prompt_tokens += log.prompt_tokens;
            completion_tokens += log.completion_tokens;

            let m = by_model.entry(log.model.clone()).or_insert((0, 0));
            m.0 += 1;
            m.1 += log.total_tokens;

            let u = by_user.entry(log.user_email.clone()).or_insert((0, 0));
            u.0 += 1;
            u.1 += log.total_tokens;

            all_logs.push(json!({
                "user_email": log.user_email,
                "model": log.model,
                "provider": log.provider,
                "prompt_tokens": log.prompt_tokens,
                "completion_tokens": log.completion_tokens,
                "total_tokens": log.total_tokens,
                "created_at_ms": log.created_at.timestamp_millis(),
            }));
        }
    }

    all_logs.reverse();
    all_logs.truncate(50);

    let model_stats: Vec<Value> = by_model
        .into_iter()
        .map(|(model, (requests, tokens))| {
            json!({ "model": model, "requests": requests, "tokens": tokens })
        })
        .collect();
    let user_stats: Vec<Value> = by_user
        .into_iter()
        .map(|(email, (requests, tokens))| {
            json!({ "email": email, "requests": requests, "tokens": tokens })
        })
        .collect();

    Ok(Json(json!({
        "total_users": users_count,
        "total_backups": backups_count,
        "total_requests": total_requests,
        "total_tokens": total_tokens,
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "by_model": model_stats,
        "by_user": user_stats,
        "recent": all_logs,
    })))
}

async fn load_ai_config(state: &AppState) -> AiConfigDoc {
    if let Some(db) = &state.db {
        let coll: Collection<AiConfigDoc> = db.collection("ai_config");
        if let Ok(Some(cfg)) = coll.find_one(doc! { "_id": "models" }).await {
            return cfg;
        }
    }
    default_ai_config()
}

async fn admin_get_models(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    require_admin(&state, &headers)?;
    let cfg = load_ai_config(&state).await;
    Ok(Json(json!({
        "version": cfg.version,
        "default_model": cfg.default_model,
        "models": cfg.models,
    })))
}

#[derive(Deserialize)]
struct SaveModelsRequest {
    default_model: String,
    models: Vec<AiModelEntry>,
}

async fn admin_save_models(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Json(payload): Json<SaveModelsRequest>,
) -> Result<Json<Value>, ApiError> {
    require_admin(&state, &headers)?;
    let db = require_db(&state)?;

    if payload.models.is_empty() {
        return Err(ApiError(StatusCode::BAD_REQUEST, "At least one model is required".into()));
    }

    let version = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        .to_string();

    let cfg = AiConfigDoc {
        id: "models".into(),
        version: version.clone(),
        default_model: payload.default_model,
        models: payload.models,
        updated_at: Some(BsonDateTime::now()),
    };

    let coll: Collection<AiConfigDoc> = db.collection("ai_config");
    let bson_models = mongodb::bson::to_bson(&cfg.models)
        .map_err(|e| ApiError(StatusCode::BAD_REQUEST, e.to_string()))?;

    coll.update_one(
        doc! { "_id": "models" },
        doc! {
            "$set": {
                "version": &cfg.version,
                "default_model": &cfg.default_model,
                "models": bson_models,
                "updated_at": BsonDateTime::now(),
            }
        },
    )
    .upsert(true)
    .await
    .map_err(|e| ApiError(StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(json!({
        "saved": true,
        "version": cfg.version,
        "default_model": cfg.default_model,
        "models": cfg.models,
    })))
}

async fn fetch_provider_models(
    state: &AppState,
    headers: &axum::http::HeaderMap,
    provider: &str,
) -> Result<Json<Value>, ApiError> {
    require_admin(state, headers)?;
    let spec = provider_spec(state, provider);
    let key = spec.keys.first().ok_or_else(|| {
        ApiError(
            StatusCode::SERVICE_UNAVAILABLE,
            format!("No {} configured", spec.env_name),
        )
    })?;

    let resp = state
        .http
        .get(spec.models_url)
        .bearer_auth(key)
        .send()
        .await
        .map_err(|e| {
            ApiError(
                StatusCode::BAD_GATEWAY,
                format!("{} error: {}", spec.id, format_error_chain(&e)),
            )
        })?;

    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(ApiError(
            StatusCode::BAD_GATEWAY,
            format!("{} error {}: {}", spec.id, status.as_u16(), extract_groq_error(&text)),
        ));
    }

    let mut parsed: Value = serde_json::from_str(&text)
        .map_err(|e| ApiError(StatusCode::BAD_GATEWAY, e.to_string()))?;

    // Google's OpenAI-compatible /models endpoint prefixes IDs with "models/".
    if spec.id == "gemini" {
        if let Some(arr) = parsed.get_mut("data").and_then(|d| d.as_array_mut()) {
            for item in arr {
                if let Some(id_val) = item.get_mut("id") {
                    if let Some(raw) = id_val.as_str() {
                        *id_val = Value::String(raw.strip_prefix("models/").unwrap_or(raw).to_string());
                    }
                }
            }
        }
    }

    Ok(Json(json!({ "provider": spec.id, "models": parsed["data"] })))
}

async fn admin_groq_models(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    fetch_provider_models(&state, &headers, "groq").await
}

async fn admin_nvidia_models(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    fetch_provider_models(&state, &headers, "nvidia").await
}

async fn admin_gemini_models(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    fetch_provider_models(&state, &headers, "gemini").await
}

async fn admin_openrouter_models(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Value>, ApiError> {
    fetch_provider_models(&state, &headers, "openrouter").await
}

async fn admin_provider_models(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Path(provider): Path<String>,
) -> Result<Json<Value>, ApiError> {
    fetch_provider_models(&state, &headers, &provider).await
}

#[derive(Deserialize)]
struct ModelsQuery {
    version: Option<String>,
}

async fn get_ai_models(
    State(state): State<AppState>,
    _auth: AuthUser,
    Query(query): Query<ModelsQuery>,
) -> Json<Value> {
    let cfg = load_ai_config(&state).await;
    if query.version.as_deref() == Some(cfg.version.as_str()) {
        return Json(json!({
            "unchanged": true,
            "version": cfg.version,
        }));
    }

    let enabled_models: Vec<AiModelEntry> = cfg
        .models
        .into_iter()
        .filter(|m| m.enabled)
        .collect();

    Json(json!({
        "unchanged": false,
        "version": cfg.version,
        "default_model": cfg.default_model,
        "models": enabled_models,
    }))
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
    auth: AuthUser,
    Json(payload): Json<AiChatRequest>,
) -> Result<Json<Value>, ApiError> {
    // Enforce admin-configured model availability and resolve provider ("groq" or "nvidia").
    let cfg = load_ai_config(&state).await;
    let matched_model = cfg.models.iter().find(|m| m.id == payload.model);
    if !cfg.models.is_empty() && !matched_model.is_some_and(|m| m.enabled) {
        return Err(ApiError(
            StatusCode::BAD_REQUEST,
            format!("Model '{}' is not enabled on the server", payload.model),
        ));
    }

    let provider = matched_model
        .map(|m| m.provider.as_str())
        .unwrap_or("groq");
    let spec = provider_spec(&state, provider);

    if spec.keys.is_empty() {
        return Err(ApiError(
            StatusCode::SERVICE_UNAVAILABLE,
            format!("No {} configured on server", spec.env_name),
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

    let total = spec.keys.len();
    let start = spec.index.fetch_add(1, Ordering::Relaxed) % total;
    let mut last_err = String::from("AI request failed");
    let mut last_status = StatusCode::TOO_MANY_REQUESTS;

    for offset in 0..total {
        let key = &spec.keys[(start + offset) % total];
        let mut body = json!({
            "model": payload.model,
            "messages": &full_messages,
            "temperature": 0.4,
            "max_tokens": 1536,
        });
        if spec.stream {
            body["stream"] = json!(true);
        }

        let resp = match build_provider_post(&state, &spec, key, &body).send().await {
            Ok(r) => r,
            Err(e) => {
                if e.is_timeout() {
                    return Err(ApiError(
                        StatusCode::GATEWAY_TIMEOUT,
                        format!(
                            "{} model '{}' timed out. Try a faster model.",
                            spec.id, payload.model
                        ),
                    ));
                }
                last_status = StatusCode::BAD_GATEWAY;
                last_err = format!("{} network error: {}", spec.id, format_error_chain(&e));
                continue;
            }
        };

        let status = resp.status();
        if status.as_u16() == 429 {
            let text = resp.text().await.unwrap_or_default();
            last_status = StatusCode::TOO_MANY_REQUESTS;
            last_err = format!("{} rate-limited (429): {text}", spec.id);
            continue;
        }
        if !status.is_success() {
            let text = resp.text().await.unwrap_or_default();
            return Err(ApiError(
                StatusCode::BAD_GATEWAY,
                format!("{} error {}: {}", spec.id, status.as_u16(), extract_groq_error(&text)),
            ));
        }

        let (content, prompt_tokens, completion_tokens, total_tokens) = if spec.stream {
            read_sse_chat_response(resp, spec.id, &payload.model).await?
        } else {
            let text = resp
                .text()
                .await
                .map_err(|e| ApiError(StatusCode::BAD_GATEWAY, format_error_chain(&e)))?;
            parse_json_chat_response(&text, spec.id, &payload.model)?
        };

        if let Some(db) = &state.db {
            let logs: Collection<UsageLogDoc> = db.collection("usage_logs");
            let _ = logs
                .insert_one(UsageLogDoc {
                    user_email: auth.email.clone(),
                    model: payload.model.clone(),
                    provider: spec.id.to_string(),
                    prompt_tokens,
                    completion_tokens,
                    total_tokens,
                    created_at: BsonDateTime::now(),
                })
                .await;
        }

        return Ok(Json(json!({ "content": content })));
    }

    Err(ApiError(last_status, last_err))
}

fn format_error_chain(err: &dyn std::error::Error) -> String {
    let mut parts = vec![err.to_string()];
    let mut cur = err.source();
    while let Some(s) = cur {
        parts.push(s.to_string());
        cur = s.source();
    }
    parts.join(" -> ")
}

fn parse_json_chat_response(
    text: &str,
    provider: &str,
    model: &str,
) -> Result<(String, u64, u64, u64), ApiError> {
    let parsed: Value =
        serde_json::from_str(text).map_err(|e| ApiError(StatusCode::BAD_GATEWAY, e.to_string()))?;
    let content = parsed["choices"][0]["message"]["content"]
        .as_str()
        .unwrap_or("")
        .trim()
        .to_string();
    if content.is_empty() {
        return Err(ApiError(
            StatusCode::BAD_GATEWAY,
            format!("{provider} returned an empty response for model '{model}'"),
        ));
    }
    let prompt_tokens = parsed["usage"]["prompt_tokens"].as_u64().unwrap_or(0);
    let completion_tokens = parsed["usage"]["completion_tokens"].as_u64().unwrap_or(0);
    let total_tokens = parsed["usage"]["total_tokens"]
        .as_u64()
        .unwrap_or(prompt_tokens + completion_tokens);
    Ok((content, prompt_tokens, completion_tokens, total_tokens))
}

fn apply_sse_line(
    line: &str,
    content: &mut String,
    prompt_tokens: &mut u64,
    completion_tokens: &mut u64,
    total_tokens: &mut u64,
) {
    let trimmed = line.trim();
    if let Some(data) = trimmed.strip_prefix("data:") {
        let data = data.trim();
        if data.is_empty() || data == "[DONE]" {
            return;
        }
        if let Ok(v) = serde_json::from_str::<Value>(data) {
            if let Some(piece) = v["choices"][0]["delta"]["content"].as_str() {
                content.push_str(piece);
            } else if let Some(full) = v["choices"][0]["message"]["content"].as_str() {
                content.push_str(full);
            }
            if v["usage"].is_object() {
                *prompt_tokens = v["usage"]["prompt_tokens"].as_u64().unwrap_or(*prompt_tokens);
                *completion_tokens = v["usage"]["completion_tokens"]
                    .as_u64()
                    .unwrap_or(*completion_tokens);
                *total_tokens = v["usage"]["total_tokens"]
                    .as_u64()
                    .unwrap_or(*prompt_tokens + *completion_tokens);
            }
        }
    }
}

async fn read_sse_chat_response(
    mut resp: reqwest::Response,
    provider: &str,
    model: &str,
) -> Result<(String, u64, u64, u64), ApiError> {
    let mut buf: Vec<u8> = Vec::new();
    let mut content = String::new();
    let mut prompt_tokens: u64 = 0;
    let mut completion_tokens: u64 = 0;
    let mut total_tokens: u64 = 0;

    while let Some(chunk) = resp.chunk().await.map_err(|e| {
        if e.is_timeout() {
            ApiError(
                StatusCode::GATEWAY_TIMEOUT,
                format!("{provider} model '{model}' timed out while streaming"),
            )
        } else {
            ApiError(
                StatusCode::BAD_GATEWAY,
                format!("{provider} stream error: {}", format_error_chain(&e)),
            )
        }
    })? {
        buf.extend_from_slice(&chunk);
        while let Some(pos) = buf.iter().position(|&b| b == b'\n') {
            let line_bytes: Vec<u8> = buf.drain(..=pos).collect();
            let line = String::from_utf8_lossy(&line_bytes);
            apply_sse_line(
                &line,
                &mut content,
                &mut prompt_tokens,
                &mut completion_tokens,
                &mut total_tokens,
            );
        }
    }

    if !buf.is_empty() {
        let tail = String::from_utf8_lossy(&buf);
        if tail.trim_start().starts_with("data:") {
            apply_sse_line(
                &tail,
                &mut content,
                &mut prompt_tokens,
                &mut completion_tokens,
                &mut total_tokens,
            );
        } else if content.is_empty() {
            return parse_json_chat_response(&tail, provider, model);
        }
    }

    let trimmed = content.trim().to_string();
    if trimmed.is_empty() {
        return Err(ApiError(
            StatusCode::BAD_GATEWAY,
            format!("{provider} returned an empty response for model '{model}'"),
        ));
    }
    Ok((trimmed, prompt_tokens, completion_tokens, total_tokens))
}

#[derive(Deserialize)]
struct TestModelRequest {
    model: String,
    #[serde(default = "default_provider")]
    provider: String,
}

async fn admin_test_model(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Json(payload): Json<TestModelRequest>,
) -> Result<Json<Value>, ApiError> {
    require_admin(&state, &headers)?;
    let spec = provider_spec(&state, &payload.provider);
    let key = spec.keys.first().ok_or_else(|| {
        ApiError(
            StatusCode::SERVICE_UNAVAILABLE,
            format!("No {} configured", spec.env_name),
        )
    })?;

    let started = std::time::Instant::now();
    let mut body = json!({
        "model": payload.model,
        "messages": [{ "role": "user", "content": "Say hi in 3 words." }],
        "temperature": 0.4,
        "max_tokens": 512,
    });
    if spec.stream {
        body["stream"] = json!(true);
    }

    let resp = tokio::time::timeout(
        std::time::Duration::from_secs(20),
        build_provider_post(&state, &spec, key, &body).send(),
    )
    .await
    .map_err(|_| {
        ApiError(
            StatusCode::GATEWAY_TIMEOUT,
            format!("Model '{}' timed out (>20s) — too slow for mobile", payload.model),
        )
    })?
    .map_err(|e| ApiError(StatusCode::BAD_GATEWAY, format_error_chain(&e)))?;

    let status = resp.status();
    if !status.is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(ApiError(
            StatusCode::BAD_GATEWAY,
            format!("HTTP {}: {}", status.as_u16(), extract_groq_error(&text)),
        ));
    }

    let (content, _, _, _) = tokio::time::timeout(std::time::Duration::from_secs(20), async {
        if spec.stream {
            read_sse_chat_response(resp, spec.id, &payload.model).await
        } else {
            let text = resp
                .text()
                .await
                .map_err(|e| ApiError(StatusCode::BAD_GATEWAY, format_error_chain(&e)))?;
            parse_json_chat_response(&text, spec.id, &payload.model)
        }
    })
    .await
    .map_err(|_| {
        ApiError(
            StatusCode::GATEWAY_TIMEOUT,
            format!("Model '{}' timed out (>20s) — too slow for mobile", payload.model),
        )
    })??;

    Ok(Json(json!({
        "ok": true,
        "latency_ms": started.elapsed().as_millis() as u64,
        "preview": content,
    })))
}

fn extract_groq_error(body: &str) -> String {
    if let Ok(v) = serde_json::from_str::<Value>(body) {
        if let Some(msg) = v["error"]["message"].as_str() {
            return msg.to_string();
        }
        if let Some(msg) = v[0]["error"]["message"].as_str() {
            return msg.to_string();
        }
    }
    if body.is_empty() {
        "No error details provided".into()
    } else {
        body.to_string()
    }
}
