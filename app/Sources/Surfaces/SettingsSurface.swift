import SwiftUI

/// The standard macOS Settings window (⌘,) — Rhythm and Sound &
/// Notifications panes (spec: add-session-settings "Settings scene").
/// Everything here is Lite; nothing here is ever paywalled.
struct SettingsSurface: View {
    static let paneTitles = ["Rhythm", "Sound & Notifications"]

    @Bindable var model: AppModel

    var body: some View {
        TabView {
            RhythmPane(model: model)
                .tabItem { Label("Rhythm", systemImage: "metronome") }
            SoundNotificationsPane(model: model)
                .tabItem { Label("Sound & Notifications", systemImage: "speaker.wave.2") }
        }
        .frame(width: 520, height: 560)
    }
}
