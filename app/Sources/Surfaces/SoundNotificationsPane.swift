import SwiftUI

/// Sound cues and local notifications (spec: add-session-settings "Sound
/// cues, all optional" / "Local notifications with honest text"). Factory
/// state is silence; every cue defaults off, and a sound is presentation,
/// never state. Text the user edits here is delivered verbatim — their words are
/// theirs. This file states no colour of its own.
struct SoundNotificationsPane: View {
    @Bindable var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sound")
                .font(.headline)
            Form {
                Section {
                    Slider(value: masterVolume, in: 0...1) {
                        Text("Volume")
                    }
                    Toggle("Tick during focus", isOn: sound(\.focusTick, set: { $0.focusTick = $1 }))
                    Toggle("Tick during breaks", isOn: sound(\.breakTick, set: { $0.breakTick = $1 }))
                    Toggle("Chime when a block completes", isOn: sound(\.focusEndChime, set: { $0.focusEndChime = $1 }))
                    Toggle("Chime when a break has run its length", isOn: sound(\.breakEndChime, set: { $0.breakEndChime = $1 }))
                    Toggle("Loop the tick continuously", isOn: sound(\.tickLoop, set: { $0.tickLoop = $1 }))
                    Text("Everything is off until you ask for it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Notifications") {
                    if model.notificationsUnavailable {
                        // Plain truth, no nag: the system said no, and the only
                        // place to change that is System Settings.
                        Text("Notifications are turned off for Praxmodoro in System Settings.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Group {
                        Toggle("Notify when a block completes", isOn: notif(\.blockEndEnabled, set: { $0.blockEndEnabled = $1 }))
                        TextField("Block-end text", text: notifText(\.blockEndText, set: { $0.blockEndText = $1 }))
                            .textFieldStyle(.roundedBorder)
                        Toggle("Notify when a break has run its length", isOn: notif(\.breakEndEnabled, set: { $0.breakEndEnabled = $1 }))
                        TextField("Break-end text", text: notifText(\.breakEndText, set: { $0.breakEndText = $1 }))
                            .textFieldStyle(.roundedBorder)
                        Toggle("Bring Praxmodoro forward from a notification", isOn: notif(\.bringToFront, set: { $0.bringToFront = $1 }))
                    }
                    .disabled(model.notificationsUnavailable)
                    Text("Edited text is yours and is delivered exactly as written.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(SurfacePalette.primaryText(increasedContrast: contrast == .increased))
        .background(SurfacePalette.background(reduceTransparency: reduceTransparency))
    }

    // MARK: Bindings onto the seam.

    private var masterVolume: Binding<Double> {
        Binding(
            get: { model.sound.masterVolume },
            set: { value in
                var sound = model.sound
                sound.masterVolume = value
                model.setSound(sound)
            })
    }

    private func sound(
        _ get: KeyPath<SoundPreferences, Bool>, set: @escaping (inout SoundPreferences, Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { model.sound[keyPath: get] },
            set: { value in
                var sound = model.sound
                set(&sound, value)
                model.setSound(sound)
            })
    }

    private func notif(
        _ get: KeyPath<NotificationPreferences, Bool>,
        set: @escaping (inout NotificationPreferences, Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { model.notifications[keyPath: get] },
            set: { value in
                var prefs = model.notifications
                set(&prefs, value)
                model.setNotifications(prefs)
            })
    }

    private func notifText(
        _ get: KeyPath<NotificationPreferences, String>,
        set: @escaping (inout NotificationPreferences, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: { model.notifications[keyPath: get] },
            set: { value in
                var prefs = model.notifications
                set(&prefs, value)
                model.setNotifications(prefs)
            })
    }
}
