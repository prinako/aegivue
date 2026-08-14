FROM rust:1.88-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock* ./
COPY crates ./crates
RUN cargo build --release --package vigilo-media

FROM debian:bookworm-slim
ENV PUID=1000 \
    PGID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates ffmpeg wget gosu passwd \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 vigilo \
    && useradd --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin vigilo \
    && mkdir -p /data/recordings \
    && chown vigilo:vigilo /data/recordings

COPY --from=build /src/target/release/vigilo-media /usr/local/bin/vigilo-media
COPY crates/media-engine/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3010
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["vigilo-media"]
