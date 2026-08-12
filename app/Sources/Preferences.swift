import Foundation
import PraxmodoroCore

/// Rhythm preferences (spec: add-session-settings). One JSON blob per family
/// on the injected defaults seam — the Motion pattern, scaled. Nothing here
/// touches the session store or its schema.
struct RhythmPreferences: Equatable, Codable {
    /// User-added focus durations in seconds; built-in policies always exist.
    var focusPresets: [TimeInterval] = []
    /// User-added break durations in seconds.
    var breakPresets: [TimeInterval] = []
    /// Every N blocks, suggest a longer break — never enforce one.
    var cadence: LongBreakCadence?
    /// What a block-end does. Shipping default is the gentle middle.
    var blockEnd: BlockEndBehaviour = .promptFirst
    /// Break end returns to focus at the canonical instant. Off by default:
    /// breaks stay open-ended unless the user asks for the rhythm.
    var autoReturn: Bool = false

    static let factory = RhythmPreferences()
    static let key = "praxmodoro.rhythm-preferences"

    static func load(from defaults: UserDefaults) -> RhythmPreferences {
        guard let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(RhythmPreferences.self, from: data)
        else { return .factory }
        return decoded
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

/// Sound preferences (spec: "Sound cues, all optional"). Factory state is
/// silence: every cue defaults off, and a sound is presentation, never state.
struct SoundPreferences: Equatable, Codable {
    var masterVolume: Double = 0.7
    var focusTick: Bool = false
    var breakTick: Bool = false
    var focusEndChime: Bool = false
    var breakEndChime: Bool = false
    var tickLoop: Bool = false

    static let factory = SoundPreferences()
    static let key = "praxmodoro.sound-preferences"

    static func load(from defaults: UserDefaults) -> SoundPreferences {
        guard let data = defaults.data(forKey: key),
            var decoded = try? JSONDecoder().decode(SoundPreferences.self, from: data)
        else { return .factory }
        decoded.masterVolume = min(1.0, max(0.0, decoded.masterVolume))
        return decoded
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

/// Notification preferences (spec: "Local notifications with honest text").
/// Shipped default texts pass the copy-tone lint; text the user edits is
/// theirs — stored and delivered verbatim, never linted at entry.
struct NotificationPreferences: Equatable, Codable {
    var blockEndEnabled: Bool = false
    var breakEndEnabled: Bool = false
    var bringToFront: Bool = false
    var blockEndText: String = Self.defaultBlockEndText
    var breakEndText: String = Self.defaultBreakEndText

    static let defaultBlockEndText = "The block is complete. Your place is kept."
    static let defaultBreakEndText = "The break has run its length. Come back when you are ready."

    static let factory = NotificationPreferences()
    static let key = "praxmodoro.notification-preferences"

    static func load(from defaults: UserDefaults) -> NotificationPreferences {
        guard let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return .factory }
        return decoded
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
