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
import Combine
import AVFoundation

// In mp4, AC-4 is carried as a "raw frame"
// In mp2ts and .ac4 files, AC-4 is carried as a "sync frame" (a.k.a. "simple"): a raw frame plus a sync word, frame size, and CRC
//
// Reference: https://www.etsi.org/deliver/etsi_ts/103100_103199/10319001/01.03.01_60/ts_10319001v010301p.pdf, Annex G AC-4 Sync Frame
//
// See also:
//  https://ott.dolby.com/OnDelKits/AC-4/Dolby_AC-4_Online_Delivery_Kit_1.5/Documentation/Specs/AC4_HLS/help_files/topics/ac4_dash_t_ac4_reading.html
//  https://ott.dolby.com/OnDelKits/AC-4/Dolby_AC-4_Online_Delivery_Kit_1.5/Documentation/Specs/AC4_HLS/help_files/topics/ac4_in_mpeg_dash_c_mp4_samp.html
//  https://ott.dolby.com/OnDelKits/AC-4/Dolby_AC-4_Online_Delivery_Kit_1.5/Documentation/Specs/AC4_HLS/help_files/topics/ac4_c_raw_ac4_frame.html

// AC4FileParser parses sync frames from an .ac4 file

class AC4FileParser: NSObject {
  var log = Logger(.ac4parser)
  var frames: [Data] = []
  private var rawBytes: [UInt8]?
  private var offset: Int = 0
  private var bytesRemaining: Int = 0
  
  func parse(data: Data) throws {
    rawBytes = [UInt8](data)
    bytesRemaining = data.count
    offset = 0
    
    repeat {
      do {
        try nextFrame()
      } catch {
        log.error("Error parsing AC-4 frames: \(error.localizedDescription)")
        throw error
      }
    } while bytesRemaining > 0
  }

  private func nextFrame() throws {
    var frameLength = 0
    var frameSize: UInt32 = 0
    var hasCRC: Bool = false

    if let bytes = rawBytes {
      
      // AC-4 sync words
      if bytesRemaining < 2 {
        throw AC4FileParserError.brokenFrameDetected
      } else {
        if bytes[0+offset] == 0xAC && bytes[1+offset] == 0x40 {
          hasCRC = false
          frameLength += 2
        } else if bytes[0+offset] == 0xAC && bytes[1+offset] == 0x41 {
          hasCRC = true
          frameLength += 2
        } else {
          throw AC4FileParserError.brokenFrameDetected
        }
      }
      
      // AC-4 frame size
      if bytesRemaining < 7 {
        throw AC4FileParserError.brokenFrameDetected
      } else {
        if bytes[2+offset] == 0xFF && bytes[3+offset] == 0xFF {
          frameSize = UInt32(bytes[4+offset]) * (1 << 16)
          frameSize += UInt32(bytes[5+offset]) * (1 << 8)
          frameSize += UInt32(bytes[6+offset])
          frameLength += 5
        } else {
          frameSize = UInt32(bytes[2+offset]) * (1 << 8)
          frameSize += UInt32(bytes[3+offset])
          frameLength += 2
        }
        frameLength += Int(frameSize)
      }
      
      // Account for the CRC, if present
      if hasCRC {
        frameLength += 2
      }
      
      // Check for partial frames
      if bytesRemaining < frameLength {
        throw AC4FileParserError.brokenFrameDetected
      }
      
      // Save the frame
      frames.append(
        Data(bytes[offset...offset+frameLength-1])
      )
      
      // Update pointers
      offset += frameLength
      bytesRemaining -= frameLength
    }
    
    return
  }

}

public enum AC4FileParserError: LocalizedError {
  case brokenFrameDetected

  public var errorDescription: String? {
    switch self {
    case .brokenFrameDetected:
      return "A broken frame was detected"
    }
  }
}
