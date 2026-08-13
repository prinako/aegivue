FROM rust:1.88-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock* ./
COPY crates ./crates
RUN cargo build --release --package vigilo-media
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates ffmpeg && rm -rf /var/lib/apt/lists/* && useradd --system --uid 10001 vigilo
COPY --from=build /src/target/release/vigilo-media /usr/local/bin/vigilo-media
USER vigilo
ENTRYPOINT ["vigilo-media"]
