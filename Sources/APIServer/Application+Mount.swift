import Foundation
internal import Vapor
import APIContract

// MARK: - RoutesBuilder Extension (Internal)

extension RoutesBuilder {
    /// Groups the routes of a service under its contract group's base path.
    ///
    /// The group is inferred from `Service.Group`, so the caller never names it.
    @discardableResult
    func mount<Service: APIService>(
        _ service: Service
    ) -> APIRoutes<Service.Group, Service> {
        let pathComponents = Service.Group.basePath.toPathComponents
        let routeGroup = self.grouped(pathComponents)
        return APIRoutes(routes: routeGroup, service: service)
    }

    /// Registers one endpoint, answering with its JSON-encoded output.
    @discardableResult
    func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, ServiceContext) async throws -> Endpoint.Output
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output: Encodable {
        let method = Vapor.HTTPMethod(rawValue: Endpoint.method.rawValue)
        let pathComponents = endpoint.subPath.toPathComponents

        self.on(method, pathComponents) { request async throws -> Response in
            let input = try request.decodeInput(Endpoint.self)

            // Throws when the endpoint requires authentication and the request carries none.
            let context = try request.buildServiceContext(for: Endpoint.self)

            let output = try await handler(input, context)

            return try request.encodeOutput(output)
        }

        return self
    }

    /// Registers an endpoint with no response body, answering `204 No Content`.
    @discardableResult
    func register<Endpoint: APIContract>(
        _ endpoint: Endpoint.Type,
        handler: @escaping @Sendable (Endpoint.Input, ServiceContext) async throws -> Void
    ) -> Self where Endpoint.Input == Endpoint, Endpoint: APIInput, Endpoint.Output == EmptyOutput {
        let method = Vapor.HTTPMethod(rawValue: Endpoint.method.rawValue)
        let pathComponents = endpoint.subPath.toPathComponents

        self.on(method, pathComponents) { request async throws -> Response in
            let input = try request.decodeInput(Endpoint.self)
            let context = try request.buildServiceContext(for: Endpoint.self)

            try await handler(input, context)

            return Response(status: .noContent)
        }

        return self
    }
}

// MARK: - Path Components Conversion

extension String {
    /// Splits a contract sub-path into route components.
    ///
    /// A `:name` segment needs no special case: the string-literal conversion already turns it
    /// into a parameter component.
    var toPathComponents: [PathComponent] {
        guard !isEmpty else { return [] }

        return self.split(separator: "/").map { PathComponent(stringLiteral: String($0)) }
    }
}
