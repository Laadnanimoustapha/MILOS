# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM rust:1.82-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Cargo manifest from rust/ subfolder for dep-caching layer
COPY rust/Cargo.toml ./Cargo.toml
# Dummy binary so cargo can resolve + download deps
RUN mkdir src && echo 'fn main(){}' > src/main.rs
RUN cargo fetch
RUN cargo build --release --bin milos-server 2>/dev/null; true
RUN rm -rf src

# Build the real binary
COPY rust/src ./src
RUN touch src/main.rs && cargo build --release --bin milos-server

# ── Stage 2: minimal runtime (~80 MB) ─────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/milos-server /usr/local/bin/milos-server

# Vercel injects PORT at runtime (usually 3000 or 8080)
ENV PORT=8080
EXPOSE 8080

CMD ["/usr/local/bin/milos-server"]
