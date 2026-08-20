# Aegivue documentation

This directory contains operational and contributor documentation for Aegivue.
Start with the guide that matches what you are trying to do:

| Guide | Use it when |
| --- | --- |
| [Development setup](development/getting-started.md) | Setting up a local checkout, running the stack, or reproducing CI checks |
| [Adding an RTSP camera](cameras/rtsp.md) | Connecting a camera or diagnosing an offline stream |
| [ADR 0001: Service boundaries](architecture/0001-service-boundaries.md) | Understanding why the API, media engine, database, and media storage are separate |

The project overview, deployment quick start, configuration reference, and current
feature status live in the repository [README](../README.md).

## Documentation conventions

- Commands are run from the repository root unless a guide says otherwise.
- Examples use the default localhost bindings from `.env.example`.
- Never commit real camera credentials or a populated `.env` file.
- Update documentation in the same pull request as behavior, configuration, or
  architecture changes.
