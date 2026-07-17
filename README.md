# Pulsar JavaScript Engine

A JavaScript engine written entirely from scratch. This means we feature our own implementation of a JavaScript VM that is **not** dependent on V8, SpiderMonkey, or JavaScriptCore.

The aim of this project is to build a highly capable JavaScript environment, designed both for running JavaScript standalone (similar to Node.js) and for embedding into other projects.

## Modules

While building this JavaScript environment, we also developed several independent modules. Each module can be used standalone from this project and is easily embeddable into other Jai projects.

- **Http_Client** - Make HTTP requests in Jai. Supports both blocking and concurrent operations.
- **Http_Server** - An HTTP server for Jai. Implements HTTP/1.1, WebSockets, Server-Sent Events, and TLS.
- **JavaScript** - The core JavaScript bytecode engine.
- **LibreSSL** - Jai bindings for LibreSSL.

## Support

If you find this project useful and would like to support its development, you can [sponsor me on GitHub](https://github.com/sponsors/caztanj) or [buy me a coffee!](https://buymeacoffee.com/caztanj)