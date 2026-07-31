import SwiftUI
import PraxmodoroStore

@main
struct PraxmodoroApp: App {
    @State private var model: AppModel

    init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Praxmodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let opened = try? LocalStore.open(at: supportDir.appendingPathComponent("praxmodoro.store"), now: Date())
        self._model = State(initialValue: AppModel(store: opened?.0))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch model.surface {
                case .initiate: InitiateSurface(model: model)
                case .focus: FocusSurface(model: model)
                case .checkin: CheckinSurface(model: model)
                default: InitiateSurface(model: model) // break/review land with atoms 5.4-5.5
                }
            }
            .frame(minWidth: 720, minHeight: 520)
        }
    }
}
