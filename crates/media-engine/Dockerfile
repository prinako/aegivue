FROM rust:1.88-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock* ./
COPY crates ./crates
RUN cargo build --release --package aegivue-media

FROM debian:bookworm-slim
ENV PUID=1000 \
    PGID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates ffmpeg wget gosu passwd \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 aegivue \
    && useradd --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin aegivue \
    && mkdir -p /data/recordings \
    && chown aegivue:aegivue /data/recordings

COPY --from=build /src/target/release/aegivue-media /usr/local/bin/aegivue-media
COPY crates/media-engine/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3010
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["aegivue-media"]
