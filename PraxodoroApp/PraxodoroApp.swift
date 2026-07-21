import PraxodoroCore
import SwiftUI

@main
struct PraxodoroApplication: App {
  static let productName = PraxodoroCore.productName
  private let stateRoot = AppPaths.stateRoot()

  var body: some Scene {
    WindowGroup(PraxodoroApplication.productName) {
      InitiateView()
        .environment(\.praxodoroStateRoot, stateRoot)
    }
    .defaultSize(width: 960, height: 720)
    .windowResizability(.contentMinSize)

    MenuBarExtra(PraxodoroApplication.productName, systemImage: "timer") {
      Text("No active session")
        .padding()
    }
  }
}

private struct PraxodoroStateRootKey: EnvironmentKey {
  static let defaultValue = AppPaths.stateRoot()
}

extension EnvironmentValues {
  var praxodoroStateRoot: URL {
    get { self[PraxodoroStateRootKey.self] }
    set { self[PraxodoroStateRootKey.self] = newValue }
  }
}
