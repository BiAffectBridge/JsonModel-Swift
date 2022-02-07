//
//  FileResultObject.swift
//  
//
//  Copyright © 2017-2021 Sage Bionetworks. All rights reserved.
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

/// `FileResult` is a result that holds a pointer to a file url.
public protocol FileResult : ResultData {
    
    /// The URL with the full path to the file-based result. This should *not*
    /// be encoded in the file result if the results are encoded and uploaded
    /// to a server. This is included for use in local file system management
    /// **only**.
    ///
    /// - note: It is the responsibility of the developer to ensure that the
    /// participant's private data is managed securely.
    var url: URL? { get }
    
    /// The relative path to the file-based result.
    var relativePath: String { get }
    
    /// The MIME content type of the result.
    /// - example: `"application/json"`
    var contentType: String? { get }
    
    /// The system clock uptime when the recorder was started (if applicable).
    var startUptime: TimeInterval? { get }
}

/// `FileResultObject` is a concrete implementation of a result that holds a pointer to a file url.
public struct FileResultObject : SerializableResultData, FileResult, Equatable {
    private enum CodingKeys : String, OrderedEnumCodingKey {
        case identifier, serializableType="type", startDate, endDate, relativePath, contentType, startUptime, jsonSchema
    }
    public private(set) var serializableType: SerializableResultType = .file
    
    public let identifier: String
    public var startDate: Date
    public var endDate: Date
    
    /// The system clock uptime when the recorder was started (if applicable).
    public let startUptime: TimeInterval?
    
    /// The URL with the full path to the file-based result. This should *not*
    /// be encoded in the file result.
    public private(set) var url: URL? = nil
    
    /// The relative path to the file-based result.
    public var relativePath: String
    
    /// The MIME content type of the result.
    public var contentType: String?
    
    /// The url for the json schema that defined the content if this file has a content type of "application/json".
    public var jsonSchema: URL?
    
    public init(identifier: String, url: URL, contentType: String? = nil, startUptime: TimeInterval? = nil, jsonSchema: URL? = nil) {
        self.identifier = identifier
        self.url = url
        self.relativePath = url.relativePath
        self.contentType = contentType
        self.startUptime = startUptime
        self.startDate = Date()
        self.endDate = Date()
    }
    
    public func deepCopy() -> FileResultObject { self }
}

extension FileResultObject : DocumentableStruct {
    public static func codingKeys() -> [CodingKey] {
        return CodingKeys.allCases
    }
    
    public static func isRequired(_ codingKey: CodingKey) -> Bool {
        guard let key = codingKey as? CodingKeys else { return false }
        return key == .identifier || key == .serializableType
    }
    
    public static func documentProperty(for codingKey: CodingKey) throws -> DocumentProperty {
        guard let key = codingKey as? CodingKeys else {
            throw DocumentableError.invalidCodingKey(codingKey, "\(codingKey) is not recognized for this class")
        }
        switch key {
        case .serializableType:
            return .init(constValue: SerializableResultType.file)
        case .identifier:
            return .init(propertyType: .primitive(.string))
        case .startDate, .endDate:
            return .init(propertyType: .format(.dateTime))
        case .contentType, .relativePath:
            return .init(propertyType: .primitive(.string))
        case .startUptime:
            return .init(propertyType: .primitive(.number))
        case .jsonSchema:
            return .init(propertyType: .format(.uri), propertyDescription: "The URL for the json schema of the JSON for this file.")
        }
    }
    
    public static func examples() -> [FileResultObject] {
        var fileResult = FileResultObject(identifier: "fileResult", url: URL(string: "file://temp/foo.json")!, contentType: "application/json", startUptime: 1234.567, jsonSchema: URL(string: "file://temp/foo.schema.json")!)
        fileResult.startDate = ISO8601TimestampFormatter.date(from: "2017-10-16T22:28:09.000-07:00")!
        fileResult.endDate = fileResult.startDate.addingTimeInterval(5 * 60)
        return [fileResult]
    }
}
