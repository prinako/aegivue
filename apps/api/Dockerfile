FROM node:22-alpine AS build
WORKDIR /src
COPY package.json ./
RUN npm install
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
ENV NODE_ENV=production \
    PUID=1000 \
    PGID=1000

WORKDIR /app

RUN apk add --no-cache su-exec \
    && addgroup -g 1000 vigilo \
    && adduser -D -H -u 1000 -G vigilo vigilo \
    && mkdir -p /data/recordings \
    && chown vigilo:vigilo /data/recordings

COPY --from=build --chown=vigilo:vigilo /src/node_modules ./node_modules
COPY --from=build --chown=vigilo:vigilo /src/dist ./dist
COPY --from=build --chown=vigilo:vigilo /src/package.json ./
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "dist/main.js"]
