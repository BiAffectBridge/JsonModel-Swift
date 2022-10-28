//
//  BranchNodeResult.swift
//  
//
//  Copyright © 2017-2022 Sage Bionetworks. All rights reserved.
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

/// The ``BranchNodeResult`` is the result created for a given level of navigation of a node tree. The
/// ``stepHistory`` is additive where each time a node is traversed, it is added to the list.
public protocol BranchNodeResult : CollectionResult {

    /// The ``stepHistory`` includes the history of the node results that were traversed as a
    /// part of running an assessment.
    var stepHistory: [ResultData] { get set }
    
    /// A list of all the asynchronous results for this assessment. The list should only include uniquely
    /// identified results.
    /// - Note: The step history is used to describe the path you took to get to where you are going,
    /// whereas the asynchronous results include any canonical results that are independent of path.
    var asyncResults: [ResultData]? { get set }

    /// The path traversed by this branch.
    var path: [PathMarker] { get set }
}

public extension BranchNodeResult {
    
    var children: [ResultData] {
        get { asyncResults ?? [] }
        set { self.asyncResults = newValue }
    }
    
    func findAnswer(with identifier:String ) -> AnswerResult? {
        for result in stepHistory.reversed() {
            if let answerResult = (result as? AnswerFinder)?.findAnswer(with: identifier) {
                return answerResult
            }
        }
        if let results = asyncResults?.reversed() {
            for result in results {
                if let answerResult = (result as? AnswerFinder)?.findAnswer(with: identifier) {
                    return answerResult
                }
            }
        }
        return nil
    }
    
    /// Find the last result in the step history.
    func findResult(with identifier: String) -> ResultData? {
        self.stepHistory.last(where: { $0.identifier == identifier })
    }
    
    /// Append the result to the end of the step history. If the last result has the same
    /// identifier, then remove it.
    /// - parameter result:  The result to add to the step history.
    /// - returns: The previous result or `nil` if there wasn't one.
    @discardableResult
    func appendStepHistory(with result: ResultData, direction: PathMarker.Direction = .forward) -> ResultData? {
        var previousResult: ResultData?
        if let idx = stepHistory.lastIndex(where: { $0.identifier == result.identifier }) {
            previousResult = (idx == stepHistory.count - 1) ? stepHistory.remove(at: idx) : stepHistory[idx]
        }
        stepHistory.append(result)
        let marker = PathMarker(identifier: result.identifier, direction: direction)
        if path.last != marker {
            path.append(marker)
        }
        return previousResult
    }
    
    /// Remove the nodePath from `stepIdentifier` to the end of the result set.
    /// - parameter stepIdentifier:  The identifier of the result associated with the given step.
    /// - returns: The previous results or `nil` if there weren't any.
    @discardableResult
    func removeStepHistory(from stepIdentifier: String) -> Array<ResultData>? {
        if let idx = path.lastIndex(where: { $0.identifier == stepIdentifier }) {
            path.removeSubrange(idx...)
        }
        guard let idx = stepHistory.lastIndex(where: { $0.identifier == stepIdentifier }) else { return nil }
        return Array(stepHistory[idx...])
    }
}

/// A path marker is used in tracking the *current* path that the user is navigating.
public struct PathMarker: Hashable, Codable {
    private enum CodingKeys : String, OrderedEnumCodingKey {
        case identifier, direction
    }
    
    /// The node identifier for this path marker.
    public let identifier: String
    
    /// The direction of navigation along a path.
    public let direction: Direction
    
    public init(identifier: String, direction: Direction) {
        self.identifier = identifier
        self.direction = direction
    }
    
    /// The direction of navigation along a path.
    public enum Direction : String, Codable, DocumentableStringEnum, StringEnumSet {
        case forward, backward, exit
    }
}

/// Abstract implementation to allow extending an assessment result while retaining the serializable type.
open class AbstractBranchNodeResultObject : AbstractResultObject {
    private enum CodingKeys : String, OrderedEnumCodingKey, OpenOrderedCodingKey {
        case stepHistory, asyncResults, path
        var relativeIndex: Int { 2 }
    }

    public var stepHistory: [ResultData]
    public var asyncResults: [ResultData]?
    public var path: [PathMarker]

    /// Default initializer for this object.
    public init(identifier: String,
                startDate: Date = Date(),
                endDate: Date? = nil,
                stepHistory: [ResultData] = [],
                asyncResults: [ResultData]? = nil,
                path: [PathMarker] = []) {
        self.stepHistory = stepHistory
        self.asyncResults = asyncResults
        self.path = path
        super.init(identifier: identifier, startDate: startDate, endDate: endDate)
    }

    /// Initialize from a `Decoder`. This decoding method will use the ``SerializationFactory`` instance associated
    /// with the decoder to decode the `stepHistory` and `asyncResults`.
    ///
    /// - parameter decoder: The decoder to use to decode this instance.
    /// - throws: `DecodingError`
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decodeIfPresent([PathMarker].self, forKey: .path) ?? []

        let resultsContainer = try container.nestedUnkeyedContainer(forKey: .stepHistory)
        self.stepHistory = try decoder.serializationFactory.decodePolymorphicArray(ResultData.self, from: resultsContainer)

        if container.contains(.asyncResults) {
            let asyncResultsContainer = try container.nestedUnkeyedContainer(forKey: .asyncResults)
            self.asyncResults = try decoder.serializationFactory.decodePolymorphicArray(ResultData.self, from: asyncResultsContainer)
        }
        
        try super.init(from: decoder)
    }

    /// Encode the result to the given encoder.
    /// - parameter encoder: The encoder to use to encode this instance.
    /// - throws: `EncodingError`
    override open func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)

        var nestedContainer = container.nestedUnkeyedContainer(forKey: .stepHistory)
        for result in stepHistory {
            let nestedEncoder = nestedContainer.superEncoder()
            try result.encode(to: nestedEncoder)
        }

        if let results = asyncResults {
            var asyncContainer = container.nestedUnkeyedContainer(forKey: .asyncResults)
            for result in results {
                let nestedEncoder = asyncContainer.superEncoder()
                try result.encode(to: nestedEncoder)
            }
        }
    }
    
    override open class func codingKeys() -> [CodingKey] {
        var keys = super.codingKeys()
        keys.append(contentsOf: CodingKeys.allCases)
        return keys
    }

    override open class func isRequired(_ codingKey: CodingKey) -> Bool {
        guard let key = codingKey as? CodingKeys else {
            return super.isRequired(codingKey)
        }
        return key == .stepHistory
    }

    override open class func documentProperty(for codingKey: CodingKey) throws -> DocumentProperty {
        guard let key = codingKey as? CodingKeys else {
            return try super.documentProperty(for: codingKey)
        }
        switch key {
        case .stepHistory:
            return .init(propertyType: .interfaceArray("\(ResultData.self)"), propertyDescription:
            """
            The ``stepHistory`` includes the history of the node results that were traversed as a
            part of running an assessment.
            """.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "  ", with: "\n"))
        case .asyncResults:
            return .init(propertyType: .interfaceArray("\(ResultData.self)"), propertyDescription:
            "A list of all the asynchronous results for this task. The list should include uniquely identified results.")
        case .path:
            return .init(propertyType: .referenceArray(PathMarker.documentableType()), propertyDescription:
                            "The path traversed by this branch.")
        }
    }
}

public final class BranchNodeResultObject : AbstractBranchNodeResultObject, SerializableResultData, BranchNodeResult {
    
    public override class func defaultType() -> SerializableResultType {
        .StandardTypes.section.resultType
    }
    
    public func deepCopy() -> BranchNodeResultObject {
        .init(identifier: identifier,
              startDate: startDateTime,
              endDate: endDateTime,
              stepHistory: stepHistory.map { $0.deepCopy() },
              asyncResults: asyncResults?.map { $0.deepCopy() },
              path: path)
    }
}

extension PathMarker : DocumentableStruct {
    public static func codingKeys() -> [CodingKey] {
        CodingKeys.allCases
    }
    
    public static func isRequired(_ codingKey: CodingKey) -> Bool {
        true
    }
    
    public static func documentProperty(for codingKey: CodingKey) throws -> DocumentProperty {
        guard let key = codingKey as? CodingKeys else {
            throw DocumentableError.invalidCodingKey(codingKey, "\(codingKey) is not recognized for this class")
        }
        switch key {
        case .identifier:
            return .init(propertyType: .primitive(.string), propertyDescription:
                            "The node identifier for this path marker.")
        case .direction:
            return .init(propertyType: .reference(PathMarker.Direction.documentableType()), propertyDescription:
                            "The direction of the path navigation.")
        }
    }
    
    public static func examples() -> [PathMarker] {
        [.init(identifier: "foo", direction: .forward)]
    }
}

extension BranchNodeResultObject : DocumentableStruct {
    
    public static func examples() -> [BranchNodeResultObject] {
        
        let result = BranchNodeResultObject(identifier: "example")

        var introStepResult = ResultObject(identifier: "introduction")
        introStepResult.startDateTime = ISO8601TimestampFormatter.date(from: "2017-10-16T22:28:09.000-07:00")!
        introStepResult.endDateTime = introStepResult.startDateTime.addingTimeInterval(20)
        
        let collectionResult = CollectionResultObject.examples().first!
        collectionResult.startDateTime = introStepResult.endDateTime!
        collectionResult.endDateTime = collectionResult.startDateTime.addingTimeInterval(2 * 60)
        
        var conclusionStepResult = ResultObject(identifier: "conclusion")
        conclusionStepResult.startDateTime = collectionResult.endDateTime!
        conclusionStepResult.endDateTime = conclusionStepResult.startDateTime.addingTimeInterval(20)

        var fileResult = FileResultObject.examples().first!
        fileResult.startDateTime = collectionResult.startDateTime
        fileResult.endDateTime = collectionResult.endDateTime
        
        result.stepHistory = [introStepResult, collectionResult, conclusionStepResult]
        result.asyncResults = [fileResult]

        result.startDateTime = introStepResult.startDateTime
        result.endDateTime = conclusionStepResult.endDateTime
        result.path = [
            .init(identifier: "introduction", direction: .forward),
            .init(identifier: collectionResult.identifier, direction: .forward),
            .init(identifier: "conclusion", direction: .forward)
        ]

        return [result]
    }
}

