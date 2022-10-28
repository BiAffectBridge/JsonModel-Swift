//
//  ResultDataSerializer.swift
//  
//
//  Copyright © 2020-2022 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import JsonModel


/// `SerializableResultData` is the base implementation for `ResultData` that is serialized using
/// the `Codable` protocol and the polymorphic serialization defined by this framework.
///
public protocol SerializableResultData : ResultData, PolymorphicRepresentable {
    var serializableType: SerializableResultType { get }
}

extension SerializableResultData {
    public var typeName: String { serializableType.stringValue }
}

/// `SerializableResultType` is an extendable string enum used by the `SerializationFactory` to
/// create the appropriate result type.
public struct SerializableResultType : TypeRepresentable, Codable, Hashable {
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public enum StandardTypes : String, CaseIterable {
        case answer, assessment, base, collection, error, file, section
        
        public var resultType: SerializableResultType {
            .init(rawValue: self.rawValue)
        }
    }
    
    /// List of all the standard types.
    public static func allStandardTypes() -> [SerializableResultType] {
        StandardTypes.allCases.map { $0.resultType }
    }
}

extension SerializableResultType : ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension SerializableResultType : DocumentableStringLiteral {
    public static func examples() -> [String] {
        return allStandardTypes().map{ $0.rawValue }
    }
}

public final class ResultDataSerializer : IdentifiableInterfaceSerializer, PolymorphicSerializer {
    public var documentDescription: String? {
        """
        The interface for any `ResultData` that is serialized using the `Codable` protocol and the
        polymorphic serialization defined by this framework.
        """.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "  ", with: "\n")
    }
    
    public var jsonSchema: URL {
        URL(string: "\(self.interfaceName).json", relativeTo: kSageJsonSchemaBaseURL)!
    }
    
    override init() {
        self.examples = [
            AnswerResultObject.examples().first!,
            CollectionResultObject.examples().first!,
            ErrorResultObject.examples().first!,
            FileResultObject.examples().first!,
            ResultObject.examples().first!,
            BranchNodeResultObject.examples().first!,
            AssessmentResultObject(),
        ]
    }
    
    public private(set) var examples: [ResultData]
    
    public override class func typeDocumentProperty() -> DocumentProperty {
        .init(propertyType: .reference(SerializableResultType.documentableType()))
    }
    
    /// Insert the given example into the example array, replacing any existing example with the
    /// same `typeName` as one of the new example.
    public func add(_ example: SerializableResultData) {
        examples.removeAll(where: { $0.typeName == example.typeName })
        examples.append(example)
    }
    
    /// Insert the given examples into the example array, replacing any existing examples with the
    /// same `typeName` as one of the new examples.
    public func add(contentsOf newExamples: [SerializableResultData]) {
        let newNames = newExamples.map { $0.typeName }
        self.examples.removeAll(where: { newNames.contains($0.typeName) })
        self.examples.append(contentsOf: newExamples)
    }
    
    private enum InterfaceKeys : String, OrderedEnumCodingKey, OpenOrderedCodingKey {
        case startDate, endDate
        var relativeIndex: Int { 2 }
    }
    
    public override class func codingKeys() -> [CodingKey] {
        var keys = super.codingKeys()
        keys.append(contentsOf: InterfaceKeys.allCases)
        return keys
    }
    
    public override class func isRequired(_ codingKey: CodingKey) -> Bool {
        guard let key = codingKey as? InterfaceKeys else {
            return super.isRequired(codingKey)
        }
        return key == .startDate
    }
    
    public override class func documentProperty(for codingKey: CodingKey) throws -> DocumentProperty {
        guard let key = codingKey as? InterfaceKeys else {
            return try super.documentProperty(for: codingKey)
        }
        switch key {
        case .startDate:
            return .init(propertyType: .format(.dateTime), propertyDescription:
                            "The start date timestamp for the result.")
        case .endDate:
            return .init(propertyType: .format(.dateTime), propertyDescription:
                            "The end date timestamp for the result.")
        }
    }
}

/// Abstract implementation to allow extending a result while retaining the serializable type.
open class AbstractResultObject : Codable, MultiplatformTimestamp {
    private enum CodingKeys : String, OrderedEnumCodingKey, OpenOrderedCodingKey {
        case serializableType = "type", identifier, startDate, endDate
        var relativeIndex: Int { 0 }
    }
    public private(set) var serializableType: SerializableResultType = "null"
    
    open class func defaultType() -> SerializableResultType {
        fatalError("Default serializable type not defined for abstract.")
    }

    public let identifier: String
    public var startDateTime: Date
    public var endDateTime: Date?

    /// Default initializer for this object.
    public init(identifier: String,
                startDate: Date = Date(),
                endDate: Date? = nil) {
        self.identifier = identifier
        self.startDateTime = startDate
        self.endDateTime = endDate
        self.serializableType = type(of: self).defaultType()
    }

    /// Initialize from a `Decoder`. This decoding method will use the ``SerializationFactory`` instance associated
    /// with the decoder to decode the `stepHistory` and `asyncResults`.
    ///
    /// - parameter decoder: The decoder to use to decode this instance.
    /// - throws: `DecodingError`
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.startDateTime = try container.decode(Date.self, forKey: .startDate)
        self.endDateTime = try container.decodeIfPresent(Date.self, forKey: .endDate)
        self.serializableType = type(of: self).defaultType()
    }

    /// Encode the result to the given encoder.
    /// - parameter encoder: The encoder to use to encode this instance.
    /// - throws: `EncodingError`
    open func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(serializableType, forKey: .serializableType)
        try container.encode(startDateTime, forKey: .startDate)
        try container.encodeIfPresent(endDateTime, forKey: .endDate)
    }
    
    open class func codingKeys() -> [CodingKey] {
        CodingKeys.allCases
    }

    open class func isRequired(_ codingKey: CodingKey) -> Bool {
        guard let key = codingKey as? CodingKeys else { return false }
        switch key {
        case .serializableType, .identifier, .startDate:
            return true
        default:
            return false
        }
    }

    open class func documentProperty(for codingKey: CodingKey) throws -> DocumentProperty {
        guard let key = codingKey as? CodingKeys else {
            throw DocumentableError.invalidCodingKey(codingKey, "\(codingKey) is not recognized for this class")
        }
        switch key {
        case .serializableType:
            return .init(constValue: defaultType())
        case .identifier:
            return .init(propertyType: .primitive(.string))
        case .startDate, .endDate:
            return .init(propertyType: .format(.dateTime))
        }
    }
}
