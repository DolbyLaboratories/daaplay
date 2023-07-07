/// Copyright (c) 2023, Dolby Laboratories Inc.
/// All rights reserved.
///
/// Redistribution and use in source and binary forms, with or without modification, are permitted
/// provided that the following conditions are met:
///
/// 1. Redistributions of source code must retain the above copyright notice, this list of conditions
///    and the following disclaimer.
/// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions
///    and the following disclaimer in the documentation and/or other materials provided with the distribution.
/// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or
///    promote products derived from this software without specific prior written permission.
///
/// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
/// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
/// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
/// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
/// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
/// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
/// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
/// OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

class AppContentParser: NSObject, ObservableObject {
  static let logger = Logger(.contentParser)
  var log: Logger {
    AppContentParser.logger
  }
  
  // MARK: Private properties
  private var content: AppContent?
  private let contentPackingList = "contentPackingList.json"
  
  func parse() throws -> AppContent? {

    try loadManifest()
    try generateURLS()
    return content
  }
  
  private func loadManifest() throws {
    do {
      try content = self.load(contentPackingList)
    } catch {
      throw AppContentError.fileCannotBeFound
    }
  }
  
  private func generateURLS() throws {
    if let content = content {
      // Music
      if let music = content.music {
        for (index, content) in music.enumerated() {
          
          let filename: String = content.audio
          var fileURL: URL?
          
          do {
            fileURL = try getURLFor(filename: filename)
          } catch {
            log.error("Cannot open \(filename)")
            throw AppContentError.fileCannotBeFound
          }
          self.content?.music?[index].audioURL = fileURL!
        }
      }
      
      // Video
      if let video = content.video {
        for (index, content) in video.enumerated() {
          
          // Video
          var filename: String = content.video
          var fileURL: URL?
          
          do {
            fileURL = try getURLFor(filename: filename)
          } catch {
            log.error("Cannot open \(filename)")
            throw AppContentError.fileCannotBeFound
          }
          self.content?.video?[index].videoURL = fileURL!
          
          // Audio
          filename = content.audio
          
          do {
            fileURL = try getURLFor(filename: filename)
          } catch {
            log.error("Cannot open \(filename)")
            throw AppContentError.fileCannotBeFound
          }
          self.content?.video?[index].audioURL = fileURL!
        }
      }
    }
  }
  
  private func getURLFor(filename: String) throws -> URL {
    let fileBase = (filename as NSString).deletingPathExtension
    let fileExtension = (filename as NSString).pathExtension

    // Create file URL
    guard let fileURL = Bundle.main.url(forResource: fileBase, withExtension: ".\(fileExtension)") else {
      log.error("Cannot open \(filename)")
      throw AppContentError.fileCannotBeFound
    }
    
    return fileURL
  }
  
  private func load<T: Decodable>(_ filename: String) throws -> T {
    let data: Data
    
    do {
      let file = try getURLFor(filename: filename)
      data = try Data(contentsOf: file)
    } catch {
      log.error("Cannot load \(filename)")
      throw AppContentError.failedToOpenPackingList
    }
    
    do {
      let decoder = JSONDecoder()
      return try decoder.decode(T.self, from: data)
    } catch {
      log.error("Cannot decode \(filename) as \(T.self):\n\(error)")
      throw AppContentError.failedToOpenPackingList
    }
  }
}

public enum AppContentError: LocalizedError {
  case failedToOpenPackingList
  case fileCannotBeFound
  
  public var errorDescription: String? {
    switch self {
    case .failedToOpenPackingList:
      return "Failed to open packing list"
    case .fileCannotBeFound:
      return "The file cannot be found"
    }
  }
}
