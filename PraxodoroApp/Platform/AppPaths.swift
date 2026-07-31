import Foundation

enum AppPaths {
  static func stateRoot(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> URL {
    if let override = environment["PRAXODORO_STATE_ROOT"], !override.isEmpty {
      return URL(filePath: override, directoryHint: .isDirectory)
    }

    return URL.applicationSupportDirectory
      .appending(component: "Praxodoro", directoryHint: .isDirectory)
  }
}
