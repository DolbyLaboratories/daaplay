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

class AudioDeviceManager: NSObject, ObservableObject {
  static let logger = Logger(.audioSession)
  var log: Logger {
    AudioDeviceManager.logger
  }
  static let shared = AudioDeviceManager()
  @Published var headphonesConnected = false
  @Published var outputName: String = ""
  @Published var outputType: AVAudioSession.Port = .builtInSpeaker
  @Published var isSpatialAudioEnabled: Bool = false

  private override init() {
    let session = AVAudioSession.sharedInstance()
    super.init()
    
    do {
      //let options: AVAudioSession.CategoryOptions = [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
      try session.setCategory(AVAudioSession.Category.playback,
                              mode: AVAudioSession.Mode.default
                              // , options: options
      )
    } catch {
      print("Error setting AVAudioSession category: \(error.localizedDescription)")
    }
    
    headphonesConnected = hasHeadphones(in: session.currentRoute)
    setupNotifications()
    updateActivePort()
  }

  func setupNotifications() {
    let notctr = NotificationCenter.default
    notctr.addObserver(self,
                       selector: #selector(handleRouteChange),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)
  }

  @objc func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }

    switch reason {

    case .newDeviceAvailable: // New device found.
      let session = AVAudioSession.sharedInstance()
      headphonesConnected = hasHeadphones(in: session.currentRoute)

    case .oldDeviceUnavailable: // Old device removed.
      let session = AVAudioSession.sharedInstance()
      headphonesConnected = hasHeadphones(in: session.currentRoute)

    default: ()
    }
    updateActivePort()
  }

  func hasHeadphones(in routeDescription: AVAudioSessionRouteDescription) -> Bool {
    let targetPorts: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothLE]
    return !routeDescription.outputs.filter({targetPorts.contains($0.portType)}).isEmpty
  }

  func hasBuiltInSpeakers(in routeDescription: AVAudioSessionRouteDescription) -> Bool {
    return !routeDescription.outputs.filter({$0.portType == .builtInSpeaker}).isEmpty
  }
  
  func isStereo(in routeDescription: AVAudioSessionRouteDescription) -> Bool {
    if let channelCount = routeDescription.outputs[0].channels?.count {
      return channelCount == 2 ? true : false
    }
    return false
  }

  func updateActivePort() {
    let session = AVAudioSession.sharedInstance()
    let route: AVAudioSessionRouteDescription = session.currentRoute
    outputName = route.outputs[0].portName
    outputType = route.outputs[0].portType
    isSpatialAudioEnabled = route.outputs[0].isSpatialAudioEnabled
    
    // Check for un-supported audio endpoints
    if !(hasHeadphones(in: route) || hasBuiltInSpeakers(in: route)) || !isStereo(in: route) {
      // Playing virtualized content over audio endpoints other than stereo headphones
      // and built-in stereo speakers is incorrect.
      //
      // A fully-featured media player is expected to switch to a non-virtualized audio
      // stream when such audio endpoints are connected.
      //
      // However, as DAAPlay does not support more than one audio stream, this app
      // prints an error message and continues.
      self.log.error("Unsupported audio port: \(self.outputName)")
    }
  }

}
