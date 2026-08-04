import Foundation

/// The complete keyboard path through the loop (spec: focus-loop-ui "Full
/// keyboard loop"). Views bind these; the accessibility suite pins coverage.
enum KeyboardMap {
    static let all: [String: String] = [
        "begin": "⌘↩",
        "hold-toggle": "Space",
        "checkin-1": "1",
        "checkin-2": "2",
        "checkin-3": "3",
        "checkin-4": "4",
        "break-ready": "R",
        "new-session": "⌘N",
        "checkin-now": "⌘K",
        "close-session": "⌘⇧W",
        "toggle-capsule": "⌘⇧F",
        "return-continue": "↩",
    ]
}
