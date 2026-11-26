# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM rust:1.82-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache deps layer: copy manifest, build a dummy binary first
COPY Cargo.toml ./Cargo.toml
RUN mkdir src && echo 'fn main(){}' > src/main.rs
RUN cargo fetch
RUN cargo build --release --bin milos-server 2>/dev/null; true
RUN rm -rf src

# Build the real binary
COPY src ./src
RUN touch src/main.rs && cargo build --release --bin milos-server

# ── Stage 2: minimal runtime ──────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/milos-server /usr/local/bin/milos-server

# Vercel injects PORT; default to 80 to match its routing
ENV PORT=80
EXPOSE 80

CMD ["/usr/local/bin/milos-server"]
