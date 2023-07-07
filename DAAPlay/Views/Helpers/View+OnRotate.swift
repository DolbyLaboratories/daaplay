import Foundation
import SwiftUI

extension View {
  func onRotate(callback: @escaping (UIDeviceOrientation) -> Void) -> some View {
    self.modifier(DeviceRotationViewModifier(action: callback))
  }
}
