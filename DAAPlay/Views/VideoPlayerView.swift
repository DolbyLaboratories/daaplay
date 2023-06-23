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

import SwiftUI
import AVFoundation
import AVKit

struct VideoPlayerView: View {
  @StateObject var viewModel = VideoPlayerViewModel()
  @Environment(\.dismiss) private var dismiss

  var title: String
  var badge: String
  var videoURL: URL
  var audioURL: URL
  
  var body: some View {
    VStack {
      ZStack {
        VideoPlayer(
          player: viewModel.videoPlayer
        )
        .disabled(true)
        
        if !(viewModel.isAudioPlayerReady && (viewModel.videoPlayer?.status == .readyToPlay)) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .tint(.white)
            .scaleEffect(4)
        }
      }
      
      HStack {
        Button {
          viewModel.playOrPause()
        } label: {
          ZStack {
            Image(systemName: viewModel.state == .playing ? "pause.fill" : "play.fill")
          }
        }
        .foregroundColor(.primary)
        .font(.system(size: 45))
        .padding(.trailing, 20)
        
        Slider(value: $viewModel.playerProgress,
               in: 0...viewModel.audioPlayer.duration,
               onEditingChanged: { scrubStarted in
          if scrubStarted {
            viewModel.scrubState = .scrubbing
          } else {
            viewModel.scrubState = .scrubEnded(viewModel.playerProgress)
          }
        })
        .accentColor(.pink)
        .padding(.bottom, 8)
      }
      .padding(.horizontal, 15)
      
      Text(title)
        .font(.headline)
      
    }
    .onAppear {
      viewModel.setup(videoURL: videoURL, audioURL: audioURL)
    }
    .onDisappear {
      viewModel.teardown()
    }
    .onReceive(viewModel.dismissPublisher) { shouldDismiss in
      if shouldDismiss {
        dismiss()
      }
    }
    .navigationBarBackButtonHidden(true)
    .navigationTitle(badge)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          dismiss()
        } label: {
          HStack {
            Image(systemName: "chevron.backward")
            Text("Back")
          }
        }
      }
    }
    .toolbar {
      if viewModel.audioDeviceManager.headphonesConnected {
        ToolbarItem(placement: .navigationBarTrailing) {
          Image(systemName: headphoneIcon)
            .foregroundColor(.primary)
            .font(.system(size: 16, weight: .semibold))
        }
      }
    }
  }
  
  private var headphoneIcon: String {
    let outputDeviceName = viewModel.audioDeviceManager.outputName.filter { !$0.isWhitespace }
    switch outputDeviceName.lowercased() {
    case "airpodsmax": return "airpodsmax"
    case "airpodspro": return "airpodspro"
    case "airpods": return "airpods.gen3"
    default: return "headphones"
    }
  }
  
}
