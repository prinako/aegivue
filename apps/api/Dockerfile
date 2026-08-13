FROM node:22-alpine AS build
WORKDIR /src
COPY package.json ./
RUN npm install
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
USER node
COPY --from=build --chown=node:node /src/node_modules ./node_modules
COPY --from=build --chown=node:node /src/dist ./dist
COPY --from=build --chown=node:node /src/package.json ./
EXPOSE 3000
CMD ["node","dist/main.js"]
