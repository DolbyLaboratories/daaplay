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

struct ExpertView: View {
  @StateObject var viewModel = ExpertViewModel()
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        
        daaView
        Divider().padding(.vertical, 10)
        avAudioSessionOutputView
        Spacer()
        
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 15)
    }
  }
  
  private var daaView: some View {
    VStack(alignment: .leading) {
      sectionHeader(name: "DAA")
      keyValuePair(key: "DAA Version", value: viewModel.daa.daaVersion)
      keyValuePair(key: "DAA API Version", value: viewModel.daa.daaAPIVersion)
      keyValuePair(key: "Core Decoder Version", value: viewModel.daa.coreDecoderVersion)
      keyValuePair(key: "DAA Latency",
                   value: String(format: "%dms (%d samples)",
                   Int(1000.0 * Double(viewModel.daa.daaLatencyInSamples) / Constants.SAMPLE_RATE),
                                 viewModel.daa.daaLatencyInSamples))
      keyValuePair(key: "Target Endpoint",
                   value: viewModel.audioDeviceManager.headphonesConnected ?
                   "Stereo headphones" : "Stereo speakers")
      statusIndicator(key: "Virtualizer", value: viewModel.daa.isVirtualized)
    }
  }
  
  private var avAudioSessionOutputView: some View {
    VStack(alignment: .leading) {
      sectionHeader(name: "AVAudioSession API")
      keyValuePair(key: "Output Name", value: viewModel.audioDeviceManager.outputName)
      keyValuePair(key: "Output Type", value: outputTypeLabel(for: viewModel.audioDeviceManager.outputType))
      statusIndicator(key: "Headphones connected", value: viewModel.audioDeviceManager.headphonesConnected)
      statusIndicator(key: "Spatial audio enabled", value: viewModel.audioDeviceManager.isSpatialAudioEnabled)
    }
  }
  
  func sectionHeader(name: String) -> some View {
    Text(name).font(.title).fontWeight(.heavy).padding(.bottom, 15)
  }
  
  func keyValuePair(key: String, value: String) -> some View {
    VStack(alignment: .leading) {
      Text(key).font(.caption2).foregroundColor(.secondary)
      Text(value)
        .font(.body)
        .foregroundColor(.primary)
        .padding(.bottom, 7)
    }
  }
  
  func keyValuePair(key: String, value: Double) -> some View {
    VStack(alignment: .leading) {
      Text(key).font(.caption2).foregroundColor(.secondary)
      Text(String(format: "%.2f", value))
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.primary)
        .padding(.bottom, 7)
    }
  }
  
  func statusIndicator(key: String, value: Bool) -> some View {
    HStack {
      let color: Color = value ? .green : .red
      Circle().fill(color).frame(width: 15, height: 15).offset(y: -3)
      Text(key).font(.body).foregroundColor(.primary).padding(.bottom, 7)
    }
  }
  
  func outputTypeLabel(for type: AVAudioSession.Port) -> String {
    switch type {
    case .airPlay:
      return "AirPlay"
    case .bluetoothA2DP:
      return "Bluetooth A2DP"
    case .bluetoothLE:
      return "Bluetooth LE"
    case .builtInSpeaker:
      return "Built-in speaker"
    case .carAudio:
      return "Car audio"
    case .HDMI:
      return "HDMI"
    case .headphones:
      return "Headphones"
    case .lineOut:
      return "Line out"
    default:
      return "Other"
    }
  }
}

struct ExpertView_Previews: PreviewProvider {
  static var previews: some View {
    ExpertView()
  }
}
