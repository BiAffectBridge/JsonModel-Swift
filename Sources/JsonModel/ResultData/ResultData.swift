//
//  ResultData.swift
//
//  Copyright © 2020 Sage Bionetworks. All rights reserved.
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

/// `ResultData` is the base protocol for an object that stores data.
///
///  syoung 12/09/2020 `ResultData` is included as a part of the JsonModel module to allow
///  progress and additions to be made to the frameworks used by SageResearch that are independant
///  of the version of https://github.com/Sage-Bionetworks/SageResearch-Apple.git that is
///  referenced by third-party frameworks. Our experience is that third-party developers will
///  pin to a specific version of SageResearch, which breaks the dependency model that we use
///  internally in our applications.
///
///  The work-around to this is to include a light-weight model here since this framework is fairly
///  static and in most cases where the `RSDResult` is referenced, those classes already import
///  JsonModel. This will allow us to divorce *our* code from SageResearch so that we can iterate
///  independently of third-party frameworks.
///
public protocol ResultData : PolymorphicTyped, DictionaryRepresentable {
    
    /// The identifier associated with the task, step, or asynchronous action.
    var identifier: String { get }
    
    /// The start date timestamp for the result.
    var startDate: Date { get set }
    
    /// The end date timestamp for the result.
    var endDate: Date { get set }
}
