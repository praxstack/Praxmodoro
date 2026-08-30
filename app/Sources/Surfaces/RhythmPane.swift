import PraxmodoroCore
import SwiftUI

/// Rhythm preferences: durations, cadence, block-end behaviour, auto-return
/// (spec: add-session-settings "Custom rhythm durations" / "Autostart
/// behaviour is the user's choice"). The pane states the flow exemption
/// rather than silently applying it. Colour and spacing come only through
/// semantic styles — this file states no colour of its own.
struct RhythmPane: View {
    /// Spec: "Flow is exempt and says so."
    static let flowExemptionNotice =
        "Flow sessions are exempt: a Flow block never ends by itself, whatever is chosen here."

    @Bindable var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var newFocusMinutes = ""
    @State private var newBreakMinutes = ""
    @State private var focusDrafts: [Int: String] = [:]
    @State private var breakDrafts: [Int: String] = [:]

    var body: some View {
        VStack(alignment: .leading) {
            Text("When a block ends")
                .font(.headline)
            Form {
                Section {
                    Picker("Block end", selection: blockEnd) {
                        Text("Break starts, declining is one key").tag(BlockEndBehaviour.offeredDefault)
                        Text("A gentle prompt asks first").tag(BlockEndBehaviour.promptFirst)
                        Text("Nothing happens until I choose").tag(BlockEndBehaviour.manual)
                    }
                    .pickerStyle(.radioGroup)
                    Toggle("Return to focus when the break has run its length", isOn: autoReturn)
                    Text(Self.flowExemptionNotice)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Focus durations") {
                    presetList(keyPath: \.focusPresets, drafts: $focusDrafts)
                    addRow(text: $newFocusMinutes, label: "Add focus minutes", keyPath: \.focusPresets)
                    presetHelp
                }

                Section("Break durations") {
                    presetList(keyPath: \.breakPresets, drafts: $breakDrafts)
                    addRow(text: $newBreakMinutes, label: "Add break minutes", keyPath: \.breakPresets)
                    presetHelp
                }

                Section("Long break") {
                    Toggle("Suggest a longer break on a cadence", isOn: cadenceEnabled)
                    if model.rhythm.cadence != nil {
                        Stepper(
                            "Every \(model.rhythm.cadence?.everyBlocks ?? 4) blocks",
                            value: cadenceBlocks, in: 2...12)
                        Stepper(
                            "Length \(Int((model.rhythm.cadence?.length ?? 900) / 60)) minutes",
                            value: cadenceMinutes, in: 5...60, step: 5)
                        Text("A suggestion, never a score — declining is ordinary.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(SurfacePalette.primaryText(increasedContrast: contrast == .increased))
        .background(SurfacePalette.background(reduceTransparency: reduceTransparency))
    }

    // MARK: Bindings onto the seam — every change lands via setRhythm.

    private func update(_ mutate: (inout RhythmPreferences) -> Void) {
        var rhythm = model.rhythm
        mutate(&rhythm)
        model.setRhythm(rhythm)
    }

    private var blockEnd: Binding<BlockEndBehaviour> {
        Binding(get: { model.rhythm.blockEnd }, set: { value in update { $0.blockEnd = value } })
    }

    private var autoReturn: Binding<Bool> {
        Binding(get: { model.rhythm.autoReturn }, set: { value in update { $0.autoReturn = value } })
    }

    private var cadenceEnabled: Binding<Bool> {
        Binding(
            get: { model.rhythm.cadence != nil },
            set: { on in
                update { $0.cadence = on ? LongBreakCadence(everyBlocks: 4, length: 15 * 60) : nil }
            })
    }

    private var cadenceBlocks: Binding<Int> {
        Binding(
            get: { model.rhythm.cadence?.everyBlocks ?? 4 },
            set: { blocks in
                update { rhythm in
                    rhythm.cadence = LongBreakCadence(
                        everyBlocks: blocks, length: rhythm.cadence?.length ?? 15 * 60)
                }
            })
    }

    private var cadenceMinutes: Binding<Int> {
        Binding(
            get: { Int((model.rhythm.cadence?.length ?? 900) / 60) },
            set: { minutes in
                update { rhythm in
                    rhythm.cadence = LongBreakCadence(
                        everyBlocks: rhythm.cadence?.everyBlocks ?? 4,
                        length: TimeInterval(minutes * 60))
                }
            })
    }

    @ViewBuilder
    private func presetList(
        keyPath: WritableKeyPath<RhythmPreferences, [TimeInterval]>,
        drafts: Binding<[Int: String]>
    ) -> some View {
        let presets = model.rhythm[keyPath: keyPath]
        if presets.isEmpty {
            Text("The built-in policies are always available.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        ForEach(Array(presets.enumerated()), id: \.offset) { index, seconds in
            let draft = Binding(
                get: { drafts.wrappedValue[index] ?? String(Int(seconds / 60)) },
                set: { drafts.wrappedValue[index] = $0 })
            HStack {
                TextField("Preset minutes", text: draft)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    var input = draft.wrappedValue
                    var rhythm = model.rhythm
                    if rhythm.commitPreset(&input, at: index, in: keyPath) {
                        model.setRhythm(rhythm)
                        drafts.wrappedValue[index] = nil
                    }
                }
                .buttonStyle(.borderless)
                Button("Remove") {
                    update { rhythm in
                        guard rhythm[keyPath: keyPath].indices.contains(index) else { return }
                        rhythm[keyPath: keyPath].remove(at: index)
                    }
                    drafts.wrappedValue.removeAll()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private func addRow(
        text: Binding<String>,
        label: String,
        keyPath: WritableKeyPath<RhythmPreferences, [TimeInterval]>
    ) -> some View {
        HStack {
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
            Button("Add") {
                var input = text.wrappedValue
                var rhythm = model.rhythm
                if rhythm.commitPreset(&input, in: keyPath) {
                    model.setRhythm(rhythm)
                    text.wrappedValue = input
                }
            }
        }
    }

    private var presetHelp: some View {
        Text(RhythmPreferences.presetHelp)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
