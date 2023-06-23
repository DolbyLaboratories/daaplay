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

struct Constants {
  static let NUM_CHANNELS: Int = 2
  static let SAMPLE_RATE: Double = 48000.0
  
  static let FIVE_MILLISECONDS: Double = 0.005
  static let ONE_HUNDRED_MILLISECONDS: Double = 0.1
  static let TWO_HUNDRED_AND_FIFTY_MILLISECONDS: Double = 0.25
  
  static let ONE_TWENTY_EIGHT_AUDIO_SAMPLES: Double = 128.0 / SAMPLE_RATE
  static let TWO_FIFTY_SIX_AUDIO_SAMPLES: Double = 256.0 / SAMPLE_RATE
  static let FIVE_TWELVE_AUDIO_SAMPLES: Double = 512.0 / SAMPLE_RATE
  
  static let AC4_SAMPLES_PER_BLOCK: Double = 256
  static let AC4_SAMPLES_PER_FRAME: Double = 2048
  static let AC4_SECONDS_PER_BLOCK: Double = AC4_SAMPLES_PER_BLOCK / SAMPLE_RATE
  static let AC4_SECONDS_PER_FRAME: Double = AC4_SAMPLES_PER_FRAME / SAMPLE_RATE
  static let DAA_AUDIO_BUFFER_SECONDS: Double = 0.0 / SAMPLE_RATE
}
