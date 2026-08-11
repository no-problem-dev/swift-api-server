# Architecture

Why the web framework is invisible, and what that costs.

## Overview

Application code that imports Vapor is coupled to Vapor: its request type appears in handler
signatures, its middleware protocol in every cross-cutting concern, its `Application` in the
composition root. This package puts a protocol boundary in the way, so the application depends on
`APIServer` and `APIServer` alone depends on the framework.

## Dependency hiding

Vapor is imported with `internal import` in every file that touches it, and every such file lives
under `Internal/`. Nothing it defines is reachable from a public signature:

```
Sources/APIServer/
├── Core/                     # Public protocols and value types
│   ├── ServerApplication.swift
│   ├── ServerEnvironment.swift
│   ├── ServerLogger.swift
│   └── HTTPStatus.swift
├── Internal/                 # The framework-backed implementations
│   ├── VaporServerApplication.swift
│   ├── APIServerRoutes.swift
│   ├── VaporMiddlewareAdapter.swift
│   ├── VaporServerRequest.swift
│   ├── VaporResponse.swift
│   └── VaporSSEBuilder.swift
├── Middleware/ Response/ Routing/ SSE/ Webhook/
└── ...
```

The boundary is enforced by the compiler rather than by convention: an `internal import` cannot
leak into a public signature without an error.

## Protocol first

Everything the application talks to is a protocol — ``ServerApplication``, ``Routes``,
``ServerMiddleware``, ``ServerRequest``, ``ServerResponse``, ``ServerLogger``. Each has exactly one
conformer here, which is the point: a second conformer is a test double, and a third would be a
different framework.

``Server/create(environment:)`` returns `some ServerApplication` rather than `any
ServerApplication`. That is not stylistic. ``ServerApplication`` has an associated `Routes` type,
and an existential would make `server.routes` unusable, so the opaque return type is what lets the
concrete implementation stay hidden while the registrar stays typed.

## Sendable throughout

Every public type is `Sendable`, and handlers are `@Sendable` closures, so route registration
compiles under strict concurrency without escape hatches at the call site. The internal types that
wrap reference-typed framework objects are `@unchecked Sendable`; each states in its own
documentation why that is sound.

## Where the abstraction is thinner than it looks

Two consequences are worth knowing before designing around this boundary.

**Middleware cannot rewrite the request.** ``ServerMiddleware/handle(request:next:)`` takes a
request and passes one to `next`, but the adapter forwards the original request regardless of what
was handed to it. A middleware can read, short-circuit, or decorate the response; it cannot change
what the handler receives.

**Path parameters are not visible to middleware.** ``ServerRequest/pathParameters`` is always empty
in the shipped implementation, because parameters are bound during route dispatch, which happens
after the chain has run. A middleware that needs the path reads it from
``ServerRequest/url``.

Neither limit affects route handlers, which receive decoded inputs and path parameters normally.

## Layering

```
┌─────────────────────────────────────┐
│         Application code            │
│   (contracts, business logic)       │
├─────────────────────────────────────┤
│            APIServer                │
│    (protocols, value types)         │
├─────────────────────────────────────┤
│         APIServer/Internal          │
│   (framework-backed conformers)     │
├─────────────────────────────────────┤
│              Vapor                  │
│   (HTTP server, routing, NIO)       │
└─────────────────────────────────────┘
```

## Dependencies

| Package | Role |
|---|---|
| [swift-api-contract](https://github.com/no-problem-dev/swift-api-contract) | Contract types, `APIService`, and the authentication requirements route registration enforces. Its types *do* appear in public signatures — this is a shared vocabulary, not a hidden dependency. |
| [vapor](https://github.com/vapor/vapor) | The HTTP server. Imported internally and absent from the public API. |
