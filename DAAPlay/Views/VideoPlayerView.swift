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
  @State private var isFullScreenVideo = false
  @State private var orientation = UIDeviceOrientation.unknown
  
  @Environment(\.dismiss) private var dismiss
  
  var title: String
  var artist: String?
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
        .padding(0)
        .frame(maxHeight: 300)
        
        if !(viewModel.isAudioPlayerReady && (viewModel.videoPlayer?.status == .readyToPlay)) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .tint(.white)
            .scaleEffect(4)
        }
      }
      
      TitleAndArtist(title: title, artist: artist)
      
      HStack(spacing: 0) {
        Slider(value: $viewModel.playerProgress,
               in: 0...viewModel.audioPlayer.duration,
               onEditingChanged: { scrubStarted in
          if scrubStarted {
            viewModel.scrubState = .scrubbing
          } else {
            viewModel.scrubState = .scrubEnded(viewModel.playerProgress)
          }
        })
        .accentColor(ColorScheme.progressAccent)
      }
      .padding(.horizontal, 20)
      
      HStack(spacing: 0) {
        Text(viewModel.elapsedTimeText)
          .font(.caption2)
          .foregroundColor(ColorScheme.foreground)
        
        Spacer()
        Text(viewModel.remainingTimeText)
          .font(.caption2)
          .foregroundColor(ColorScheme.foreground)
      }
      .padding(.horizontal, 20)
      .baselineOffset(20)
      
      HStack {
        Button {
          viewModel.playOrPause()
        } label: {
          ZStack {
            Image(systemName: viewModel.state == .playing ? "pause.fill" : "play.fill")
          }
        }
        .foregroundColor(ColorScheme.foreground)
        .font(.system(size: 45, weight: .thin))
        .padding(.trailing, 16)
        
        Button {
          viewModel.seek(by: -10)
        } label: {
          Image(systemName: "gobackward.10")
        }
        .font(.system(size: 32, weight: .thin))
        .padding(.trailing, 16)
        .foregroundColor(ColorScheme.foreground)
      }
      
      Spacer()
      
      Text(badge)
        .font(.body)
        .fontWeight(Font.Weight.thin)
        .foregroundColor(ColorScheme.actionButton)
      
    }
    .fullScreenCover(isPresented: $isFullScreenVideo, content: FullScreenVideoView.init)
    .environmentObject(viewModel)
    .onAppear {
      viewModel.setup(videoURL: videoURL, audioURL: audioURL, title: title, artist: artist)
    }
    .onDisappear {
      viewModel.teardown()
    }
    .onReceive(viewModel.dismissPublisher) { shouldDismiss in
      if shouldDismiss {
        isFullScreenVideo = false
        dismiss()
      }
    }
    .background(ColorScheme.backgroundGradient)
    .accentColor(ColorScheme.foreground)
    .navigationBarBackButtonHidden(true)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          dismiss()
        } label: {
          HStack {
            Image(systemName: "chevron.backward")
            //Text("Back")
            Text("    ")
          }
        }
      }
    }
    .toolbar {
      if viewModel.audioSystemManager.headphonesConnected {
        ToolbarItem(placement: .navigationBarTrailing) {
          Image(systemName: headphoneIcon)
              .foregroundColor(ColorScheme.actionButton)
              .font(.system(size: 20, weight: .semibold))
        }
      }
    }
    .onRotate { newOrientation in
      if isFullScreenVideo == false && (newOrientation == .landscapeLeft || newOrientation == .landscapeRight) {
        isFullScreenVideo = true
      } else if isFullScreenVideo == true && (newOrientation == .portrait || newOrientation == .portraitUpsideDown) {
        isFullScreenVideo = false
      }
    }
  }
  
  private var headphoneIcon: String {
    let outputDeviceName = viewModel.audioSystemManager.outputName.filter { !$0.isWhitespace }
    switch outputDeviceName.lowercased() {
    case "airpodsmax": return "airpodsmax"
    case "airpodspro": return "airpodspro"
    case "airpods": return "airpods.gen3"
    default: return "headphones"
    }
  }
}
