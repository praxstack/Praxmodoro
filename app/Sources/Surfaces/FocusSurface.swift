import PraxmodoroCore
import SwiftUI

/// The timer holds the task; the field is ambient presence. No element here
/// scores the user (spec: focus-loop-ui "Nothing scores the user").
struct FocusSurface: View {
    /// Control catalog — tests pin the absence of scoring elements.
    static let controls = [
        "task-line", "next-action-line", "companion-field", "time-remaining",
        "hold-toggle", "thought-parking-input", "parked-thoughts-list",
        "checkin-response", "block-end-offer", "adjust-controls",
    ]

    /// The prompt-first offer, in the product's voice: an invitation with no
    /// urgency and no judgment (spec: "Prompt-first asks gently").
    static let blockEndOfferText = "The block is complete — your place is kept. Take the break?"

    @Bindable var model: AppModel
    let snapshot: SessionSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thoughtDraft = ""

    init(model: AppModel, snapshot: SessionSnapshot) {
        self.model = model
        self.snapshot = snapshot
    }

    var taskText: String { snapshot.taskLine }
    var nextActionText: String { snapshot.nextAction }
    var fieldState: String { snapshot.phase == .held ? "held" : "breathing" }
    var showsBlockEndPrompt: Bool { snapshot.offersBlockEndPrompt }
    var remainingReadout: RemainingReadout { RemainingReadout(display: snapshot.display) }

    /// The response to the check-in just answered, if any — the product
    /// answering back in its own words (GitHub #3; spec: check-in responses
    /// never grade).
    var checkinResponseText: String? { model.lastCheckinResponse }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Now focusing").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text(taskText).font(.title2.weight(.semibold))
                        .accessibilityIdentifier("task-line")
                    if !nextActionText.isEmpty {
                        Text("Next: \(nextActionText)").foregroundStyle(.secondary)
                            .accessibilityIdentifier("next-action-line")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let response = checkinResponseText {
                    Text(response)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("checkin-response")
                        .accessibilityAddTraits(.updatesFrequently)
                }

                ZStack {
                    CompanionFieldView(
                        state: fieldState,
                        motionStilled: model.fieldIsStilled(systemReduceMotion: reduceMotion),
                        pulseSignal: model.fieldPulse
                    )
                    .frame(width: 260, height: 260)
                    .accessibilityIdentifier("companion-field")
                    .accessibilityElement()
                    .accessibilityLabel(snapshot.accessibilitySummary)
                    remainingReadout
                }

                // Non-modal by construction: an ordinary card among the
                // controls, never a sheet or an alert wall.
                if showsBlockEndPrompt {
                    VStack(spacing: 8) {
                        Text(Self.blockEndOfferText)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 10) {
                            Button("Take the break") { try? model.acceptBlockEndOffer() }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.return, modifiers: [])
                            Button("Not yet") { model.dismissBlockEndOffer() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(12)
                    .accessibilityIdentifier("block-end-offer")
                }

                HStack(spacing: 10) {
                    if snapshot.offersAdjustment {
                        Button("−1 min") { model.rewindMinute() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut("-", modifiers: [])
                            .accessibilityLabel("Take a minute back")
                    }
                    Button {
                        try? model.toggleHold()
                    } label: {
                        Image(systemName: snapshot.phase == .held ? "play.fill" : "pause.fill")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .clipShape(Circle())
                    .keyboardShortcut(.space, modifiers: [])
                    .accessibilityLabel(snapshot.phase == .held ? "Resume timer" : "Hold timer")
                    .accessibilityIdentifier("hold-toggle")
                    .focusable()
                    if snapshot.offersAdjustment {
                        Button("+1 min") { model.forwardMinute() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut("+", modifiers: [])
                            .accessibilityLabel("Give the block a minute")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("adjust-controls")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Thought parking").font(.headline)
                Text("Capture without changing context.").font(.caption).foregroundStyle(.secondary)
                ForEach(model.parkedThoughts, id: \.self) { thought in
                    Text(thought).font(.callout)
                }
                .accessibilityIdentifier("parked-thoughts-list")
                TextField("Park a thought…", text: $thoughtDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("thought-parking-input")
                    .onSubmit {
                        try? model.parkThought(thoughtDraft)
                        thoughtDraft = ""
                    }
            }
            .frame(width: 240)
        }
        .padding(32)
    }
}
