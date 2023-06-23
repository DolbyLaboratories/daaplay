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
import AVFoundation
import Combine

@objc
class AudioPlayerDAA: AVAudioPlayerNode, AudioPlayer, ObservableObject {
  static let logger = Logger(.player)
  var log: Logger {
    AudioPlayerDAA.logger
  }

  @Published var daaVersion: String = ""
  @Published var daaAPIVersion: String = ""
  @Published var coreDecoderVersion: String = ""
  @Published var daaLatencyInSamples: Int = 0
  
  @Published var endpoint: Endpoint = .headphones
  @Published var isVirtualized: Bool = true
  
  @Published var state: PlayerState = .stopped
  public var statePublisher: Published<PlayerState>.Publisher { $state }
  
  public var duration: TimeInterval = 0
  public var progress: Double {
    return Double(currentFrame) * Constants.AC4_SECONDS_PER_FRAME
  }

  private var scheduledTime: TimeInterval = 0
  private var renderTimeEpoch: TimeInterval = 0
  private var renderTimeEpochAdjustment: TimeInterval = 0

  private let parser = AC4FileParser()
  private let decoder = DAADecoder()
  private var currentFrame = 0
  private var priorLastRenderTime: TimeInterval?
  private var hasStarted: Bool {
    return priorLastRenderTime == nil ? false : true
  }
  private var forceResync: Bool = false
  
  private var interruptPlayingBuffer: Bool = false

  private let outputFormat = AVAudioFormat(
    standardFormatWithSampleRate: Constants.SAMPLE_RATE,
    channels: UInt32(Constants.NUM_CHANNELS))

  private let daaDecoderQueue = DispatchQueue(label: "daa.decoder.queue")
  private var schedulingTimer: Timer?

  // MARK: - Init
  override init() {
    super.init()
    
    // Open DAA Decoder
    decoder.createDecoder(for: DAADecoderAC4Simple, isHeadphone: endpoint == .headphones, isVirtualized: isVirtualized)
    
    daaVersion = decoder.daaVersion
    daaAPIVersion = decoder.daaAPIVersion
    coreDecoderVersion = decoder.coreDecoderVersion
    daaLatencyInSamples = Int(decoder.latencyInSamples)
  }

  // MARK: - Deinit
  deinit {
    schedulingTimer?.invalidate()
    schedulingTimer = nil
    decoder.end()
  }

  // MARK: - Open file

  func openFile(url: URL) throws -> AVAudioFormat? {
    do {
      // Read the entire .ac4 file into memory
      let data = try Data(contentsOf: url)

      // Parse out each frame
      try parser.parse(data: data)

      // Assume AC-4 frame rate is 2048 samp/frame
      duration = Double(parser.frames.count) * Constants.AC4_SECONDS_PER_FRAME

      // A timer schedules decoded audio to at least DAA_AUDIO_BUFFER_SECONDS ahead of buffer exhaustion
      schedulingTimer = Timer.scheduledTimer(
        timeInterval: Constants.FIVE_TWELVE_AUDIO_SAMPLES,
        target: self,
        selector: #selector(schedulingCallback),
        userInfo: nil,
        repeats: true)

      return outputFormat

    } catch {
      log.error("Error reading the audio file: \(error.localizedDescription)")
      throw error
    }
  }
  
  // MARK: Scheduling callback
  
  @objc func schedulingCallback(_: Timer) {
    // Initialize the render time epoch
    if !hasStarted {
      // Experimentation suggests the initial render time is equivalent to 2 x the reported ioBufferDuration
      self.renderTimeEpoch = -2 * AVAudioSession.sharedInstance().ioBufferDuration
    } else {
      // Apply any adjustments to the render time
      self.renderTimeEpoch += self.renderTimeEpochAdjustment
      self.renderTimeEpochAdjustment = 0
    }
    
    if self.state == .playing {
      
      if let nodeTime = self.lastRenderTime, let playerTime = self.playerTime(forNodeTime: nodeTime) {
        let currentRenderTime = TimeInterval(playerTime.sampleTime) / playerTime.sampleRate
        var estimatedBufferedTime = self.scheduledTime - (currentRenderTime - self.renderTimeEpoch)
        
        // When an audio device is connected/disconnected, a higher level player may lose A/V sync
        // if, for example, an AVPlayer pauses while an AVAudioEngine does not. To mitigate,
        // the higher level player may force a re-sync when an audio device is connected or disconnected.
        if forceResync {
          renderTimeEpoch = currentRenderTime - scheduledTime
          forceResync = false
        }
        
        // AVAudioPlayerNode.lastRenderTime can "jump" forward, when a new audio device is connected.
        // Detect these timeline discontinutities, and compensate by adjusting the renderTimeEpoch
        if let priorLastRenderTime = self.priorLastRenderTime {
          if (currentRenderTime - priorLastRenderTime) > (8 * Constants.TWO_FIFTY_SIX_AUDIO_SAMPLES) {
            renderTimeEpoch = currentRenderTime - scheduledTime
            self.priorLastRenderTime = currentRenderTime
            // Don't schedule audio this time
            return
          }
        }
        self.priorLastRenderTime = currentRenderTime
        
  //        self.log.debug(
  //          "Scheduled: \(self.scheduledTime) Render: \(currentRenderTime) Est buffered: \(estimatedBufferedTime)")
        
        // At start-up, the decoder will consume its own start-up samples, and this loop will
        // iterate multiple times.
        //
        // In normal operation, this loop may operate 0..N times:
        //
        //  - If the callback interval is less than the iOS output buffer size (observed at
        //    480-1024 audio samples, depending upon the connected device), the estimatedBufferedTime
        //    may not change from one callback to the next, as the prior output samples
        //    have not yet been rendered by the iOS (i.e. currentRenderTime may not change
        //    between consecutive calls. In this case, the loop may iterate 0 times.
        //
        //  - When the above occurs, and when the prior output samples are finally rendered
        //    by iOS, the loop may iterate N times to catch up.
        while estimatedBufferedTime < Constants.DAA_AUDIO_BUFFER_SECONDS {
          do {
            let didSchedule = try self.scheduleNextAudio()
            if didSchedule == false { break }
          } catch {}
          estimatedBufferedTime = self.scheduledTime - (currentRenderTime - self.renderTimeEpoch)
        }
      }
    }
  }

  // MARK: Play, Pause

  override func play() {
    _ = playAndDetectStartOfStream()
  }
  
  func playAndDetectStartOfStream() -> Bool {
    var isStartOfStream: Bool = false
    var isEndOfStream: Bool = false

    // The following order of operations is critical
    
    //  1. If EOS, reset currentFrame and scheduled time
    if currentFrame == parser.frames.count {
      isEndOfStream = true
      currentFrame = 0
      scheduledTime = 0
    }
    
    //  2. Detect start of stream
    isStartOfStream = currentFrame == 0
    
    //  3. Play
    super.play()

    //  4. If EOF, reset the render time epoch
    if isEndOfStream {
      if let nodeTime = self.lastRenderTime,
         let playerTime = self.playerTime(forNodeTime: nodeTime) {
        renderTimeEpoch = TimeInterval(playerTime.sampleTime) / playerTime.sampleRate
      }
    }

    //  5. Finally, set state to playing, which unlocks the timer to start scheduling audio
    state = .playing
    
    return isStartOfStream
  }

  func pauseAndResync() -> Double {
    if hasStarted {
      self.pause()
      self.forceResync = true
    }
    return self.progress
  }
  
  override func pause() {
    state = .paused
    super.pause()
  }

  // MARK: Decoder configuration
  
  func setEndpoint(endp: Endpoint) {
    endpoint = endp
    self.decoder.setHeadphoneEndpoint(endpoint == .headphones)
  }

  // MARK: Schedule audio

  private func scheduleNextAudio() throws -> Bool {
    var didSchedule: Bool = false
    do {
      didSchedule = try daaDecoderQueue.sync {
        // Check for final frame
        if currentFrame >= parser.frames.count {
          // EOF
          return false
        }
        
        // log.debug("scheduling frame \(self.currentFrame)")
        
        if self.decoder.isReadyToDecode() {
          
          // Decode next frame
          if !self.decoder.decode(parser.frames[currentFrame], timestamp: 0) {
            throw AudioPlayerDAAError.failedToDecode
          }
          currentFrame += 1
          
          // Track latency
          daaLatencyInSamples = Int(self.decoder.latencyInSamples)
        }
        
        guard let decodedBlock = self.decoder.nextBlock()
        else {
          throw AudioPlayerDAAError.failedToDecode
        }
        
        assert(decodedBlock.buffer.frameCapacity == Int(Constants.AC4_SAMPLES_PER_BLOCK))
        
        // At start-up, the decoder may output empty or partial (i.e. < 256 samples) blocks
        // After start-up, the decoder will regularly output 256 samples per call
        if decodedBlock.buffer.frameLength > 0 {
          
          // Convert buffer format
          guard let opf = outputFormat
          else { throw AudioPlayerDAAError.failedToCreatePCMBuffer }
          guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: opf, frameCapacity: decodedBlock.buffer.frameLength),
                let converter = AVAudioConverter(from: decodedBlock.buffer.format, to: opf)
          else { throw AudioPlayerDAAError.failedToCreatePCMBuffer }
          
          try converter.convert(to: outputBuffer, from: decodedBlock.buffer)
          
          // If interrupting, the next buffer should overwrite un-rendered audio in AVAudioEngine's output buffer
          var options: AVAudioPlayerNodeBufferOptions = []
          if interruptPlayingBuffer {
            options.insert(.interrupts)
            interruptPlayingBuffer = false
          }
          
          // Schedule buffer
          if currentFrame >= parser.frames.count {
            scheduleBuffer(outputBuffer, at: nil, options: options, completionCallbackType: .dataPlayedBack) { _ in
              self.pause()
            }
          } else {
            scheduleBuffer(outputBuffer, at: nil, options: options)
          }
          
          scheduledTime += Double(decodedBlock.buffer.frameLength) / Constants.SAMPLE_RATE
        }
        return true
      }
    }
    return didSchedule
  }

  // MARK: Trick play

  func seek(offset: Double) -> Double {
    let seekFrame: Int = currentFrame + Int(offset / Constants.AC4_SECONDS_PER_FRAME)
    return seek(frame: seekFrame)
  }

  func seek(time: Double) -> Double {
    let seekFrame: Int = Int(time / Constants.AC4_SECONDS_PER_FRAME)
    return seek(frame: seekFrame)
  }

  func seek(frame: Int) -> Double {
    let wasPlaying = state == .playing
    var seekFrame = frame

    // Don't seek before the start
    seekFrame = max(seekFrame, 0)

    // Do not seek if the seek would take us past the end
    if seekFrame > parser.frames.count - 1 {
      return Double(parser.frames.count) * Constants.AC4_SECONDS_PER_FRAME
    }

    pause()

    // Adjust timing
    renderTimeEpochAdjustment -= Double(seekFrame - currentFrame) * Constants.AC4_SECONDS_PER_FRAME
    currentFrame = seekFrame
    scheduledTime = Double(seekFrame) * Constants.AC4_SECONDS_PER_FRAME

    // Any playing buffer should be interrupted upon restart
    interruptPlayingBuffer = true
    
    if wasPlaying {
      play()
    }
    
    return scheduledTime
  }
}

public enum AudioPlayerDAAError: LocalizedError {
  case failedToDecode
  case failedToCreatePCMBuffer

  public var errorDescription: String? {
    switch self {
    case .failedToDecode:
      return "Failed to decode"
    case .failedToCreatePCMBuffer:
      return "Failed to create a PCM buffer"
    }
  }
}
