import AppKit
import Foundation
import os

/// The seam between background observation policy (AppModel, tested) and the
/// run-loop timer that carries it while every window is closed (change:
/// fix-menubar-launch-hang). The model names a canonical engine instant; the
/// scheduler only wakes it there. It never reads the clock and never decides
/// anything about the session.
@MainActor
protocol ObservationScheduling: AnyObject {
    /// Replace any pending wake with one at `instant`. An instant already
    /// past fires on the next run-loop turn.
    func schedule(at instant: Date, _ fire: @escaping @MainActor () -> Void)
    func cancel()
}

/// The default for every model that is not the running app: tests drive
/// observation explicitly, and a stray wake mid-test would be a second clock.
@MainActor
final class InertObservationScheduler: ObservationScheduling {
    func schedule(at instant: Date, _ fire: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

/// Production scheduler: one wall-clock-dated, non-repeating timer on the
/// main run loop. Run-loop timers do not age while the Mac sleeps and do not
/// follow a changed system clock, so wake and clock changes re-arm the same
/// instant; an instant that passed meanwhile fires on the next turn, after
/// the wake notification's own observers (the model's `handleSystemWake`)
/// have run.
@MainActor
final class EdgeObservationScheduler: ObservationScheduling {
    private var pending: (instant: Date, fire: @MainActor () -> Void)?
    private var timer: Timer?
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    /// How many times a timer has been armed; tests read it to prove wake
    /// re-arming without sleeping the machine.
    private(set) var armCount = 0
    private static let log = Logger(subsystem: "com.praxstack.praxmodoro", category: "observation")

    init(
        wakeCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        clockCenter: NotificationCenter = .default
    ) {
        for (center, name) in [
            (wakeCenter, NSWorkspace.didWakeNotification),
            (clockCenter, Notification.Name.NSSystemClockDidChange),
        ] {
            let token = center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.arm() }
            }
            observers.append((center, token))
        }
    }

    isolated deinit {
        timer?.invalidate()
        for observer in observers { observer.center.removeObserver(observer.token) }
    }

    func schedule(at instant: Date, _ fire: @escaping @MainActor () -> Void) {
        pending = (instant, fire)
        arm()
    }

    func cancel() {
        pending = nil
        timer?.invalidate()
        timer = nil
    }

    private func arm() {
        timer?.invalidate()
        timer = nil
        guard let instant = pending?.instant else { return }
        let timer = Timer(fire: instant, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.firePending() }
        }
        // Common modes, so a wake still lands while the menu-bar popover or a
        // menu is tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        armCount += 1
        Self.log.info("observation armed for \(instant.ISO8601Format(), privacy: .public)")
    }

    private func firePending() {
        guard let (instant, fire) = pending else { return }
        Self.log.info("observation fired for \(instant.ISO8601Format(), privacy: .public)")
        pending = nil
        timer = nil
        fire()
    }
}
