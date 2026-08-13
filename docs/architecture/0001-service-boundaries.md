# ADR 0001: Service boundaries

Vigilo uses a TypeScript control plane and a Rust media data plane. PostgreSQL owns configuration and metadata; the configured filesystem owns media. The API communicates with the media engine through private internal HTTP. Media ports remain private.

This separation prevents media work from blocking API requests and gives every camera an isolated supervised Tokio task and FFmpeg child. PostgreSQL owns desired state; the media manager reconciles enabled cameras on startup and periodically. A camera is only removed after its worker stops, and the database prevents deletion while recordings reference it. Camera credentials are accepted on writes but omitted from all read models and structured logs.
