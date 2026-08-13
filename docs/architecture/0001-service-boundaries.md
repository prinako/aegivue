# ADR 0001: Service boundaries

Vigilo uses a TypeScript control plane, a Rust media data plane, and an optional Python AI worker. PostgreSQL owns configuration and metadata; the configured filesystem owns media. The API will communicate with the media engine through an explicit local-host contract, initially HTTP, once camera orchestration is implemented. Media ports remain private.

This separation prevents decode work from blocking API requests and allows each camera to run in an isolated supervised task. Camera credentials are accepted on writes but omitted from all read models and structured logs.
