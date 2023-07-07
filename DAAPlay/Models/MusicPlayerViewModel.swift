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

import SwiftUI
import AVFoundation
import Combine

class MusicPlayerViewModel: NSObject, RCExecutor, ObservableObject {
  static let logger = Logger(.viewModel)
  var log: Logger {
    MusicPlayerViewModel.logger
  }

  // MARK: Public properties

  @Published var isPlayerReady = false
  @Published var audioSystemManager = AudioSystemManager.shared
  @Published var playerProgress: Double = .zero
  @Published var elapsedTimeText: String = "00:00"
  @Published var remainingTimeText: String = "00:00"
  @Published var state: PlayerState = .stopped
  var dismissPublisher = PassthroughSubject<Bool, Never>()
  
  public var scrubState: ScrubState = .reset {
    didSet {
      switch scrubState {
      case .reset:
        return
      case .scrubbing:
        return
      case .scrubEnded(let seekTime):
        self.seek(to: seekTime)
        scrubState = .reset
      }
    }
  }

  var player: AudioPlayer = AudioPlayerDAA()

  // MARK: Private properties

  private let engine = AVAudioEngine()
  private var displayUpdateTimer: Timer?
  private var cancellables = Set<AnyCancellable>()
  private var shouldDismiss = false {
    didSet {
      dismissPublisher.send(shouldDismiss)
    }
  }

  // MARK: - Public

  func setup(audioURL: URL, title: String, artist: String?) {
    setupAudio(url: audioURL)
    audioSystemManager.activate()
    displayUpdateTimer = Timer.scheduledTimer(
      timeInterval: Constants.TWO_HUNDRED_AND_FIFTY_MILLISECONDS,
      target: self,
      selector: #selector(updateDisplay),
      userInfo: nil,
      repeats: true)
    NowPlaying.start(title: title, artist: artist, index: 0, count: 1)
    RemoteCommand.start(using: self)
  }
  
  // MARK: - Teardown
  
  func teardown() {
    pause()
    engine.stop()
    engine.reset()
    cancellables.removeAll()
    scrubState = .reset
    state = .stopped
    playerProgress = .zero
    isPlayerReady = false
    displayUpdateTimer?.invalidate()
    displayUpdateTimer = nil
    isPlayerReady = false
    player = AudioPlayerDAA()
    audioSystemManager.deactivate()
    NowPlaying.stop()
    RemoteCommand.stop()
  }
  
  deinit {
    teardown()
  }

  // MARK: - Setup audio

  private func setupAudio(url: URL) {
    var format: AVAudioFormat?

    do {
      format = try player.openFile(url: url)
      guard let avf = format else {
        return
      }
      player.setEndpoint(endp: audioSystemManager.headphonesConnected ? .headphones : .speakers)
      configureEngine(with: avf)

    } catch {
      print("Error reading the audio file: \(error.localizedDescription)")
    }
    
    // If the engine stops when the app goes inactive, then dismiss the parent view and return to the main menu
    let notctr = NotificationCenter.default
    notctr.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
      self.shouldDismiss = !self.engine.isRunning
    }
  }

  // MARK: - Configure engine

  private func configureEngine(with format: AVAudioFormat) {
    // Respond to headphone connect/disconnects
    audioSystemManager
      .$headphonesConnected
      .sink(receiveValue: { headphonesConnected in
        _ = self.player.pauseAndResync()
        self.player.setEndpoint(endp: headphonesConnected ? .headphones : .speakers)
      })
      .store(in: &cancellables)

    // Follow updates in the player state
    player
      .statePublisher
      .receive(on: RunLoop.main)
      .sink(receiveValue: { state in
        if state != self.state {
          self.state = state
        }
      })
      .store(in: &cancellables)

    // "format" is the (binaural) AVAudioFormat produced by AudioPlayerDAA
    
    // Most AVAudioEngine-based apps rely upon the engine to automatically connect the engine's
    // internal "mainMixer" and "output" nodes. However, this app makes the connection explicit
    // as it ensures audio sent to the output node is tagged as binaural. This step is crucial
    // for managing on-device virtualization.
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
    engine.prepare()

    // Minimize latency due to OS's IO buffer
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setPreferredIOBufferDuration(Constants.FIVE_MILLISECONDS)
    } catch {
      log.warning("Failed call to setPreferredIOBufferDuration()")
    }
    
//    log.debug("player: latency: \(self.player.latency)")
//    log.debug("player: outputPresentationLatency: \(self.player.outputPresentationLatency)")
//    log.debug("mixer: latency: \(self.engine.mainMixerNode.latency)")
//    log.debug("mixer: outputPresentationLatency: \(self.engine.mainMixerNode.outputPresentationLatency)")
//    log.debug("session: outputLatency: \(session.outputLatency)")
//    log.debug("session: ioBufferDuration: \(session.ioBufferDuration)")

    do {
      try engine.start()
      isPlayerReady = true
    } catch {
      print("Error configuring engine: \(error.localizedDescription)")
    }
  }

  // MARK: - Player controls

  func togglePlayPause() {

    if player.isPlaying {
      pause()
    } else {
      play()
    }
  }

  func play() {
    player.play()
  }

  func pause() {
    player.pause()
  }

  func seek(by: Double) {
    DispatchQueue.main.async {
      _ = self.player.seek(offset: by)
      self.updateDisplay()
    }
  }
  
  func seek(to seekTime: Double) {
    _ = player.seek(time: seekTime)
    updateDisplay()
  }
  
  // MARK: - Remote commands
  
  func executeRemote(command: Command) {
    switch command {
    case .pause: pause()
    case .play: play()
    case .togglePlayPause: togglePlayPause()
    case .skipForward(let offset): seek(by: offset)
    case .skipBackward(let offset): seek(by: -offset)
    case .changePlaybackPosition(let position): seek(to: position)
    }
  }
  
  // MARK: - Display updates

  @objc private func updateDisplay() {
    var currentTime: TimeInterval = 0
    if state != .stopped {
      currentTime = player.progress
    }
    
    currentTime = max(currentTime, 0)
    currentTime = min(currentTime, player.duration)
    
    // Update the player progress and time indicators
    switch self.scrubState {
    case .reset:
      playerProgress = player.progress
      elapsedTimeText = formatMinutesSeconds(time: currentTime)
      remainingTimeText = formatMinutesSeconds(time: ceil(player.duration - currentTime))
    case .scrubbing:
      elapsedTimeText = formatMinutesSeconds(time: playerProgress)
      remainingTimeText = formatMinutesSeconds(time: ceil(player.duration - playerProgress))
    case .scrubEnded(let seekTime):
      scrubState = .reset
      playerProgress = seekTime
      elapsedTimeText = formatMinutesSeconds(time: playerProgress)
      remainingTimeText = formatMinutesSeconds(time: ceil(player.duration - playerProgress))
    }
    NowPlaying.update(
      playing: state == .playing,
      rate: state == .playing ? 1.0 : 0.0,
      position: player.progress,
      duration: player.duration
    )
  }

}
