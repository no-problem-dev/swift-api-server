import APIContract
import Foundation
import Vapor

// MARK: - Test API Group

@APIGroup(path: "test", auth: .none)
public enum TestAPI {
    @Endpoint(.get, path: "items")
    public struct ListItems {
        @QueryParam public var limit: Int?
        @QueryParam public var offset: Int?

        public typealias Output = [TestItem]
    }

    @Endpoint(.get, path: "items/:itemId")
    public struct GetItem {
        @PathParam public var itemId: String

        public typealias Output = TestItem
    }

    @Endpoint(.post, path: "items")
    public struct CreateItem {
        @Body public var body: CreateItemBody

        public typealias Output = TestItem
    }

    @Endpoint(.delete, path: "items/:itemId")
    public struct DeleteItem {
        @PathParam public var itemId: String

        public typealias Output = EmptyOutput
    }
}

// MARK: - Protected API Group (requires auth)

@APIGroup(path: "protected", auth: .required)
public enum ProtectedAPI {
    @Endpoint(.get, path: "secret")
    public struct GetSecret {
        public typealias Output = SecretData
    }

    @Endpoint(.delete, path: "resource/:resourceId")
    public struct DeleteResource {
        @PathParam public var resourceId: String

        public typealias Output = EmptyOutput
    }
}

// MARK: - Test Models

public struct TestItem: Content, Equatable, Sendable {
    public let id: String
    public let name: String
    public let createdAt: Date

    public init(id: String, name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct CreateItemBody: Content, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct SecretData: Content, Sendable {
    public let secret: String

    public init(secret: String) {
        self.secret = secret
    }
}

// MARK: - Test Errors

public enum TestAPIError: APIContractError {
    case itemNotFound(id: String)
    case invalidName(reason: String)
    case unauthorized

    public var statusCode: Int {
        switch self {
        case .itemNotFound: return 404
        case .invalidName: return 400
        case .unauthorized: return 401
        }
    }

    public var errorCode: String {
        switch self {
        case .itemNotFound: return "ITEM_NOT_FOUND"
        case .invalidName: return "INVALID_NAME"
        case .unauthorized: return "UNAUTHORIZED"
        }
    }

    public var message: String {
        switch self {
        case .itemNotFound(let id): return "Item not found: \(id)"
        case .invalidName(let reason): return "Invalid name: \(reason)"
        case .unauthorized: return "Unauthorized access"
        }
    }
}

// MARK: - Test Handler

public struct TestAPIServiceImpl: TestAPIService {
    private var items: [String: TestItem] = [:]

    public init() {}

    public func handle(_ input: TestAPI.ListItems, context: ServiceContext) async throws -> [TestItem] {
        var result = Array(items.values)

        if let offset = input.offset {
            result = Array(result.dropFirst(offset))
        }
        if let limit = input.limit {
            result = Array(result.prefix(limit))
        }

        return result
    }

    public func handle(_ input: TestAPI.GetItem, context: ServiceContext) async throws -> TestItem {
        guard let item = items[input.itemId] else {
            throw TestAPIError.itemNotFound(id: input.itemId)
        }
        return item
    }

    public func handle(_ input: TestAPI.CreateItem, context: ServiceContext) async throws -> TestItem {
        let name = input.body.name
        if name.isEmpty {
            throw TestAPIError.invalidName(reason: "Name cannot be empty")
        }

        let item = TestItem(id: UUID().uuidString, name: name)
        return item
    }

    public func handle(_ input: TestAPI.DeleteItem, context: ServiceContext) async throws {
        // Just succeed for testing
    }
}

// MARK: - Protected Handler

public struct ProtectedAPIServiceImpl: ProtectedAPIService {
    public init() {}

    public func handle(_ input: ProtectedAPI.GetSecret, context: ServiceContext) async throws -> SecretData {
        SecretData(secret: "top-secret-value")
    }

    public func handle(_ input: ProtectedAPI.DeleteResource, context: ServiceContext) async throws {
        // Just succeed for testing
    }
}
