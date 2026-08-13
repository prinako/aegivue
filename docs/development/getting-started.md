# Development setup

Copy `.env.example` to `.env`, replace the database password, then run `docker compose up --build`. The API is available on `127.0.0.1:3000`; OpenAPI UI is at `/docs`.

Quality checks:

```sh
npm install && npm run typecheck && npm test && npm run build
cargo fmt --check && cargo clippy --all-targets --all-features -- -D warnings && cargo test
docker compose config
```
