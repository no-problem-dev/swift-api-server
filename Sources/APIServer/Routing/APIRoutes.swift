import Foundation
internal import Vapor
import APIContract

/// A mounted service's endpoints, already scoped to its contract group's base path.
///
/// Returned by `mount(_:)`. Because it conforms to `APIRouteRegistrar`, the `registerAll` method
/// generated for a contract group takes it directly and registers every endpoint at once:
///
/// ```swift
/// FormulaAPI.registerAll(server.routes.mount(formulaService))
/// ```
///
/// Registering by hand with `register(_:handler:)` is equally valid, but nothing checks that the
/// set is complete — an endpoint left out is simply not served.
public struct APIRoutes<Group: APIContractGroup, Service: APIService>: APIRouteRegistrar, @unchecked Sendable
where Service.Group == Group {
    let routes: RoutesBuilder

    /// The mounted service, so `registerAll` can reach the handlers.
    public let service: Service

    init(routes: RoutesBuilder, service: Service) {
        self.routes = routes
        self.service = service
    }

    /// Registers one endpoint, answering with its JSON-encoded output.
    ///
    /// The handler is called with the decoded input and a context reflecting the endpoint's
    /// authentication requirement; a request that fails that requirement is rejected before the
    /// handler runs.
    @discardableResult
    public func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, ServiceContext) async throws -> Endpoint.Output
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output: Encodable {
        routes.register(endpoint, handler: handler)
        return self
    }

    /// Registers an endpoint with no response body, answering `204 No Content`.
    @discardableResult
    public func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, ServiceContext) async throws -> Void
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output == EmptyOutput {
        routes.register(endpoint, handler: handler)
        return self
    }
}
