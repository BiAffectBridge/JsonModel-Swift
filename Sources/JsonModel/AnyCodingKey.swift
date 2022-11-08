//
//  AnyCodingKey.swift
//  
//

import Foundation


/// `CodingKey` for converting a decoding container to a dictionary where any key in the
/// dictionary is accessible.
public struct AnyCodingKey: OrderedCodingKey, Hashable {
    public let stringValue: String
    public let intValue: Int?
    public var sortOrderIndex: Int? { intValue }
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
    
    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }
    
    init(stringValue: String, orderedKeys: [CodingKey]) {
        var index: Int? = nil
        if let codingKeyIndex = orderedKeys.firstIndex(where: { $0.stringValue == stringValue }) {
            if let codingKey = orderedKeys[codingKeyIndex] as? OrderedCodingKey, let sortIndex = codingKey.sortOrderIndex {
                // keys that are indexed use the prescribed sort order.
                index = sortIndex + ((codingKey as? OpenOrderedCodingKey)?.relativeIndex ?? 0) * 1000
            }
            else {
                // Keys that are ordered but not indexed go at the bottom.
                index = codingKeyIndex + 1000000
            }
        }
        self.stringValue = stringValue
        self.intValue = index
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.stringValue)
    }
    
    public static func == (lhs: AnyCodingKey, rhs: AnyCodingKey) -> Bool {
        lhs.stringValue == rhs.stringValue
    }
}

/// Wrapper for any codable array.
public struct AnyCodableArray : Codable, Hashable {
    let array : [JsonSerializable]
    
    public init(_ array : [JsonSerializable]) {
        self.array = array
    }
    
    public init(from decoder: Decoder) throws {
        var genericContainer = try decoder.unkeyedContainer()
        self.array = try genericContainer._decode(Array<JsonSerializable>.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        try (self.array as NSArray).encode(to: encoder)
    }
    
    public static func == (lhs: AnyCodableArray, rhs: AnyCodableArray) -> Bool {
        return (lhs.array as NSArray).isEqual(to: rhs.array)
    }
    
    public func hash(into hasher: inout Hasher) {
        (array as NSArray).hash(into: &hasher)
    }
}

/// Wrapper for any codable dictionary.
public struct AnyCodableDictionary : Codable, Hashable {
    public let orderedDictionary : [AnyCodingKey : JsonSerializable]
    
    public var dictionary : [String : JsonSerializable] {
        orderedDictionary._mapKeys { $0.stringValue }
    }

    public init(_ dictionary : [String : JsonSerializable], orderedKeys: [String] = []) {
        self.orderedDictionary = dictionary._mapKeys {
            .init(stringValue: $0, intValue: orderedKeys.firstIndex(of: $0))
        }
    }
    
    public init(_ dictionary : [String : JsonSerializable], orderedKeys: [CodingKey]) {
        self.orderedDictionary = dictionary._mapKeys {
            .init(stringValue: $0, orderedKeys: orderedKeys)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let genericContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        self.orderedDictionary = try genericContainer._decode(Dictionary<AnyCodingKey, JsonSerializable>.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try orderedDictionary.forEach { (key, value) in
            let nestedEncoder = container.superEncoder(forKey: key)
            try value.encode(to: nestedEncoder)
        }
    }
    
    public static func == (lhs: AnyCodableDictionary, rhs: AnyCodableDictionary) -> Bool {
        return (lhs.dictionary as NSDictionary).isEqual(to: rhs.dictionary)
    }
    
    public func hash(into hasher: inout Hasher) {
        (dictionary as NSDictionary).hash(into: &hasher)
    }
}

/// Extension of the keyed decoding container for decoding to any dictionary. These methods are defined internally
/// to avoid possible namespace clashes.
extension KeyedDecodingContainer {
    
    /// Decode this container as a `Dictionary<String, Any>`.
    fileprivate func _decode(_ type: Dictionary<AnyCodingKey, JsonSerializable>.Type) throws -> Dictionary<AnyCodingKey, JsonSerializable> {
        var dictionary = Dictionary<AnyCodingKey, JsonSerializable>()
        
        for codingKey in allKeys {
            let key: AnyCodingKey = .init(stringValue: codingKey.stringValue,
                                          intValue: allKeys.firstIndex(where: { $0.stringValue == codingKey.stringValue }))
            if let boolValue = try? decode(Bool.self, forKey: codingKey) {
                dictionary[key] = boolValue
            }
            else if let intValue = try? decode(Int.self, forKey: codingKey) {
                dictionary[key] = intValue
            }
            else if let stringValue = try? decode(String.self, forKey: codingKey) {
                dictionary[key] = stringValue
            }
            else if let doubleValue = try? decode(Double.self, forKey: codingKey) {
                dictionary[key] = doubleValue
            }
            else if let nestedDictionary = try? decode(AnyCodableDictionary.self, forKey: codingKey) {
                dictionary[key] = nestedDictionary.dictionary
            }
            else if let nestedArray = try? decode(AnyCodableArray.self, forKey: codingKey) {
                dictionary[key] = nestedArray.array
            }
        }
        return dictionary
    }
}

/// Extension of the unkeyed decoding container for decoding to any array. These methods are defined internally
/// to avoid possible namespace clashes.
extension UnkeyedDecodingContainer {
    
    /// For the elements in the unkeyed contain, decode all the elements.
    mutating fileprivate func _decode(_ type: Array<JsonSerializable>.Type) throws -> Array<JsonSerializable> {
        var array: [JsonSerializable] = []
        while isAtEnd == false {
            if let value = try? decode(Bool.self) {
                array.append(value)
            } else if let value = try? decode(Int.self) {
                array.append(value)
            } else if let value = try? decode(Double.self) {
                array.append(value)
            } else if let value = try? decode(String.self) {
                array.append(value)
            } else if let nestedArray = try? decode(AnyCodableArray.self) {
                array.append(nestedArray.array)
            } else {
                let nestedDictionary = try decode(AnyCodableDictionary.self)
                array.append(nestedDictionary.dictionary)
            }
        }
        return array
    }
}

extension FactoryEncoder {
    
    /// Serialize a dictionary. This is a work around for not being able to
    /// directly encode a generic dictionary.
    public func encodeDictionary(_ value: Dictionary<String, Any>) throws -> Data {
        let anyDictionary = AnyCodableDictionary(value.jsonDictionary())
        let data = try self.encode(anyDictionary)
        return data
    }
    
    /// Serialize an array. This is a work around for not being able to
    /// directly encode a generic dictionary.
    public func encodeArray(_ value: Array<Any>) throws -> Data {
        let anyArray = AnyCodableArray(value.jsonArray())
        let data = try self.encode(anyArray)
        return data
    }
}

extension FactoryDecoder {
    
    /// Use this dictionary to decode the given object type.
    public func decode<T>(_ type: T.Type, from dictionary: Dictionary<String, Any>) throws -> T where T : Decodable {
        let jsonDictionary = dictionary.jsonDictionary()
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDictionary, options: [])
        let decodable = try self.decode(type, from: jsonData)
        return decodable
    }
    
    /// Use this array to decode an array of objects of the given type.
    public func decode<T>(_ type: Array<T>.Type, from array: Array<Any>) throws -> Array<T> where T : Decodable {
        let jsonArray = array.jsonArray()
        let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])
        let decodable = try self.decode(type, from: jsonData)
        return decodable
    }
    
    /// Use this jsonElement to decode the given object type.
    public func decode<T>(_ type: T.Type, from jsonElement: JsonElement) throws -> T where T : Decodable {
        let jsonData = try self.serializationFactory.createJSONEncoder().encode([jsonElement])
        let decodable = try self.decode([T].self, from: jsonData)
        guard let first = decodable.first else {
            let context = DecodingError.Context(codingPath: [], debugDescription: "Decoding returned null object.")
            throw DecodingError.dataCorrupted(context)
        }
        return first
    }
}

extension Dictionary {
    
    /// Returns a `Dictionary` containing the results of transforming the keys
    /// over `self` where the returned values are the mapped keys.
    /// - parameter transform: The function used to transform the input keys into the output key
    /// - returns: A dictionary of key/value pairs.
    internal func _mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            let transformedKey = transform(key)
            result[transformedKey] = value
        }
        return result
    }
}
