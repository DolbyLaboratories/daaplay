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

struct MainMenuView: View {
  @StateObject var viewModel = MainMenuViewModel()
  
  var body: some View {
    if let content = viewModel.content {
      NavigationView {
        List {
          
          // Music
          if let music = content.music {
            musicSection(for: music)
          }
          
          // Video
          if let video = content.video {
            videoSection(for: video)
          }
        }
        .navigationTitle("DAAPlay")
        //.navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            NavigationLink {
              ExpertView()
            } label: {
              Image(systemName: "gearshape.fill")
            }
          }
        }
      }
    }
  }
  
  func musicSection(for music: [Content.Music]) -> some View {
    Section(header: Text("Music")) {
      ForEach(music) { content in
        NavigationLink {
          MusicPlayerView(
            title: content.title,
            artist: content.artist,
            badge: content.badge,
            audioURL: content.audioURL!)
        } label: {
          contentLabel(title: content.title, artist: content.artist, duration: content.duration, badge: content.badge)
        }
      }
    }
  }
  
  func videoSection(for video: [Content.Video]) -> some View {
    Section(header: Text("Video")) {
      ForEach(video) { content in
        NavigationLink {
          VideoPlayerView(
            title: content.title,
            badge: content.badge,
            videoURL: content.videoURL!,
            audioURL: content.audioURL!)
        } label: {
          contentLabel(title: content.title, artist: nil, duration: content.duration, badge: content.badge)
        }
      }
    }
  }
  
  func contentLabel(title: String, artist: String?, duration: Int, badge: String) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title).font(.body).fontWeight(.heavy)
        if let artist = artist {
          Text(artist).font(.body)
        }
        Text(badge).font(.caption).padding(.bottom, 3)
      }
      Spacer()
      Text(formatMinutesSeconds(time: duration))
    }
  }
  
}
