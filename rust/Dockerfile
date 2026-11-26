# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM rust:1.85-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache deps layer
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

ENV PORT=8080
EXPOSE 8080

CMD ["/usr/local/bin/milos-server"]
