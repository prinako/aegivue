FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY pubspec.yaml analysis_options.yaml ./
RUN flutter pub get
COPY lib ./lib
COPY web ./web
COPY assets ./assets
RUN flutter build web --release

FROM nginx:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN mkdir -p /usr/share/nginx-default && \
    cp -a /etc/nginx/. /usr/share/nginx-default/
COPY --chmod=755 docker-entrypoint.d/00-init-nginx-volume.sh /docker-entrypoint.d/00-init-nginx-volume.sh
COPY --from=build /src/build/web /usr/share/nginx/html
VOLUME ["/etc/nginx/"]
HEALTHCHECK CMD wget -q --spider http://127.0.0.1/ || exit 1
