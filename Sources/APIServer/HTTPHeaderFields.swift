/// A set of HTTP header fields, looked up without regard to case.
///
/// Field names are case-insensitive by specification, and HTTP/2 and HTTP/3 go further and require
/// them to be sent lowercased — so `Origin` and `origin` are the same field, and a lookup that
/// compares names literally finds nothing for every request a modern browser makes.
///
/// Lookup folds the name; storage keeps the spelling it was given, so a field written as
/// `Content-Type` goes back out that way. A field written twice under different spellings is one
/// field, and the last write decides both its value and its spelling.
///
/// ## Example
/// ```swift
/// let fields: HTTPHeaderFields = ["Content-Type": "application/json"]
/// fields["content-type"]  // "application/json"
/// ```
public struct HTTPHeaderFields: Sendable, Equatable, ExpressibleByDictionaryLiteral {
    private struct Field: Sendable {
        var name: String
        var value: String
    }

    /// Keyed by lowercased name, so lookup ignores case without losing the original spelling.
    private var storage: [String: Field]

    /// Creates an empty set.
    public init() {
        self.storage = [:]
    }

    /// Creates a set from name/value pairs.
    ///
    /// - Parameter fields: The fields, keyed by name in any case.
    public init(_ fields: [String: String]) {
        self.storage = [:]
        storage.reserveCapacity(fields.count)
        for (name, value) in fields {
            storage[name.lowercased()] = Field(name: name, value: value)
        }
    }

    public init(dictionaryLiteral elements: (String, String)...) {
        self.storage = [:]
        storage.reserveCapacity(elements.count)
        for (name, value) in elements {
            storage[name.lowercased()] = Field(name: name, value: value)
        }
    }

    /// Reads or writes a field's value, matching its name without regard to case.
    ///
    /// - Parameter name: The field name, in any case.
    public subscript(_ name: String) -> String? {
        get { storage[name.lowercased()]?.value }
        set {
            guard let newValue else {
                storage[name.lowercased()] = nil
                return
            }
            storage[name.lowercased()] = Field(name: name, value: newValue)
        }
    }

    /// Reports whether a field is present, regardless of its value.
    ///
    /// - Parameter name: The field name, in any case.
    public func contains(_ name: String) -> Bool {
        storage[name.lowercased()] != nil
    }

    /// Every field, keyed by name as it was written.
    public var all: [String: String] {
        var result: [String: String] = [:]
        result.reserveCapacity(storage.count)
        for field in storage.values {
            result[field.name] = field.value
        }
        return result
    }

    /// Whether there are no fields.
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// Returns these fields with the given ones applied, replacing any of the same name.
    ///
    /// - Parameter others: The fields to add or replace.
    public func replacing(_ others: HTTPHeaderFields) -> HTTPHeaderFields {
        var result = self
        for (key, field) in others.storage {
            result.storage[key] = field
        }
        return result
    }

    /// Two sets are equal when they carry the same fields with the same values. Spelling is not
    /// part of a field's identity, so it is not part of equality either.
    public static func == (lhs: HTTPHeaderFields, rhs: HTTPHeaderFields) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        return lhs.storage.allSatisfy { key, field in rhs.storage[key]?.value == field.value }
    }
}
