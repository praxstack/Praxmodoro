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
        let model = AppModel(store: opened?.0)
        try? model.restore()
        self._model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch model.surface {
                case .initiate: InitiateSurface(model: model)
                case .focus: FocusSurface(model: model)
                case .checkin: CheckinSurface(model: model)
                case .onBreak: BreakSurface(model: model)
                case .review: ReviewSurface(model: model)
                }
            }
            .frame(minWidth: 720, minHeight: 520)
        }
    }
}
