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
import MediaPlayer

class NowPlaying {
  
  static func start(title: String, artist: String?, index: Int, count: Int) {
    
    let npic = MPNowPlayingInfoCenter.default()
    var np = [String: Any]()
      
    np = npic.nowPlayingInfo ?? [String: Any]()
    
    np[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    np[MPNowPlayingInfoPropertyIsLiveStream] = false
    np[MPMediaItemPropertyTitle] = title
    if let artist = artist {
      np[MPMediaItemPropertyArtist] = artist
    }
    np[MPNowPlayingInfoPropertyPlaybackQueueIndex] = index
    np[MPNowPlayingInfoPropertyPlaybackQueueCount] = count
    np[MPMediaItemPropertyPlaybackDuration] = nil
    np[MPNowPlayingInfoPropertyElapsedPlaybackTime] = nil
    np[MPNowPlayingInfoPropertyPlaybackRate] = nil
    np[MPNowPlayingInfoPropertyDefaultPlaybackRate] = nil
    
    npic.nowPlayingInfo = np
  }
  
  static func update(playing: Bool, rate: Float, position: Double, duration: Double) {
    
    let npic = MPNowPlayingInfoCenter.default()
    var np = npic.nowPlayingInfo ?? [String: Any]()
    
    np[MPMediaItemPropertyPlaybackDuration] = Float(duration)
    np[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float(position)
    np[MPNowPlayingInfoPropertyPlaybackRate] = rate
    np[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
    
    npic.nowPlayingInfo = np
  }
  
  static func stop() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [String: Any]()
  }
}
