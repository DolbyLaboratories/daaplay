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
import AVKit

struct FullScreenVideoView: View {
  @EnvironmentObject var viewModel: VideoPlayerViewModel
  // @Environment(\.dismiss) var dismiss
  
  var body: some View {
    ZStack {
      Color.primary.edgesIgnoringSafeArea(.all)
      
      VideoPlayer(
        player: viewModel.videoPlayer
      )
      .disabled(true)
      
      VStack {
        HStack {
          // Top row
        }
        
        Spacer()
        
        HStack {
          Button {
            viewModel.playOrPause()
          } label: {
            ZStack {
              Image(systemName: viewModel.state == .playing ? "pause.fill" : "play.fill")
            }
          }
          .font(.system(size: 32, weight: .thin))
          .padding(.trailing, 15)
          .padding(.bottom, 8)
          .foregroundColor(ColorScheme.foreground)
          
          Button {
            viewModel.seek(by: -10)
          } label: {
            Image(systemName: "gobackward.10")
          }
          .font(.system(size: 24, weight: .thin))
          .padding(.trailing, 15)
          .padding(.bottom, 8)
          .foregroundColor(ColorScheme.foreground)
          
          Spacer()
          
          Slider(value: $viewModel.playerProgress,
                 in: 0...viewModel.audioPlayer.duration,
                 onEditingChanged: { scrubStarted in
            if scrubStarted {
              viewModel.scrubState = .scrubbing
            } else {
              viewModel.scrubState = .scrubEnded(viewModel.playerProgress)
            }
          })
          .accentColor(ColorScheme.progressAccentFullScreen)
          .padding(.bottom, 8)
          
          Text(viewModel.elapsedTimeText)
            .font(.system(size: 14, weight: .light))
            .foregroundColor(ColorScheme.foreground)
            .padding(.bottom, 8)
        }
      }
    }
  }
}
