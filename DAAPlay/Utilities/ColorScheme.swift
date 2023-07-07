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

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct ColorScheme {

  static let skyBlue = Color(hex: 0x8ECAE6)
  static let prussianBlue = Color(hex: 0x023047)
  static let indigoDye = Color(hex: 0x154055)
  static let cadetGray = Color(hex: 0x8198A3)
  static let selectiveYellow = Color(hex: 0xFFB703)
  static let gray = Color(hex: 0x808080)
  static let silver = Color(hex: 0xB3B3B3)
  
  static let foreground: Color = Color.white
  static let foregroundDisabled: Color = ColorScheme.gray
  static let background: Color = ColorScheme.prussianBlue
  static let backgroundGradient: LinearGradient = LinearGradient(
                                                    colors: [
                                                      ColorScheme.background,
                                                      ColorScheme.indigoDye
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .center)
  static let actionButton: Color = ColorScheme.skyBlue
  static let progressAccent: Color = ColorScheme.selectiveYellow
  static let progressAccentFullScreen: Color = ColorScheme.silver
  static let toggleOff: Color = ColorScheme.cadetGray
  static let toggleOn: Color = ColorScheme.selectiveYellow
}
