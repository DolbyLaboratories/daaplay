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

enum Command {
  case pause, play, togglePlayPause
  case skipForward(TimeInterval)
  case skipBackward(TimeInterval)
  case changePlaybackPosition(TimeInterval)
}

protocol RCExecutor: AnyObject {
  func executeRemote(command: Command)
}

class RemoteCommand {
  
  static func start(using handler: RCExecutor) {
    let commandCenter = MPRemoteCommandCenter.shared()
    
    commandCenter.pauseCommand.addTarget { [weak handler] _ in
      guard let handler = handler else { return .noActionableNowPlayingItem }
      handler.executeRemote(command: .pause)
      return .success
    }
    
    commandCenter.playCommand.addTarget { [weak handler] _ in
      guard let handler = handler else { return .noActionableNowPlayingItem }
      handler.executeRemote(command: .play)
      return .success
    }
    
    commandCenter.togglePlayPauseCommand.addTarget { [weak handler] _ in
      guard let handler = handler else { return .noActionableNowPlayingItem }
      handler.executeRemote(command: .togglePlayPause)
      return .success
    }
    
    commandCenter.nextTrackCommand.isEnabled = false
    commandCenter.previousTrackCommand.isEnabled = false
    
    commandCenter.skipForwardCommand.preferredIntervals = [10.0]
    commandCenter.skipForwardCommand.addTarget { [weak handler] event in
      guard let handler = handler,
            let event = event as? MPSkipIntervalCommandEvent
      else { return .noActionableNowPlayingItem }
      
      handler.executeRemote(command: .skipForward(event.interval))
      return .success
    }
    
    commandCenter.skipBackwardCommand.preferredIntervals = [10.0]
    commandCenter.skipBackwardCommand.addTarget { [weak handler] event in
      guard let handler = handler,
            let event = event as? MPSkipIntervalCommandEvent
      else { return .noActionableNowPlayingItem }
      
      handler.executeRemote(command: .skipBackward(event.interval))
      return .success
    }
    
    commandCenter.changePlaybackPositionCommand.addTarget { [weak handler] event in
      guard let handler = handler,
            let event = event as? MPChangePlaybackPositionCommandEvent
      else { return .noActionableNowPlayingItem }
      
      handler.executeRemote(command: .changePlaybackPosition(event.positionTime))
      return .success
    }
  }
  
  static func stop() {
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.pauseCommand.removeTarget(nil)
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.togglePlayPauseCommand.removeTarget(nil)
    commandCenter.nextTrackCommand.removeTarget(nil)
    commandCenter.previousTrackCommand.removeTarget(nil)
    commandCenter.skipForwardCommand.removeTarget(nil)
    commandCenter.skipBackwardCommand.removeTarget(nil)
    commandCenter.changePlaybackPositionCommand.removeTarget(nil)
  }
}
