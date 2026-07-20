## ADDED Requirements

### Requirement: Semantic surface roles
The design system SHALL distinguish Functional Glass, Instrument, and Content surfaces so visual effects follow semantic purpose rather than arbitrary blur values.

#### Scenario: Functional control surface
- **WHEN** a toolbar, navigation cluster, compact control, or popover is rendered with full effects enabled
- **THEN** the system may use native Liquid Glass through the Functional Glass role

#### Scenario: Reading surface
- **WHEN** task text, settings, history, or long-form content is rendered
- **THEN** the system uses an opaque or standard semantic Content surface with legibility taking precedence over glass

#### Scenario: Timer instrument
- **WHEN** the focus dial or another core status instrument is rendered
- **THEN** the system uses the dimensional Instrument role with semantic colors, restrained depth, and no dependency on translucent text backgrounds

### Requirement: Native-first effect implementation
The first shipping slice SHALL use Apple platform effects, gradients, Canvas/Metal APIs, symbols, and typography without a third-party runtime effects dependency or network-loaded font.

#### Scenario: Dependency audit
- **WHEN** the app target's resolved runtime packages and resources are inspected
- **THEN** no third-party effect framework or remote font request is present

#### Scenario: Future effect package proposal
- **WHEN** a third-party visual package is proposed later
- **THEN** its license, maintenance, security, performance, binary size, accessibility fallback, and removal path are approved in a separate decision before adoption

### Requirement: Automatic reduced-transparency path
The system SHALL derive render policy from macOS Reduce Transparency and SHALL replace every glass/material surface with an opaque semantic surface when enabled.

#### Scenario: Reduce Transparency enabled
- **WHEN** Reduce Transparency becomes active in the main window, menu bar, compact surface, overlay, or dialog
- **THEN** all translucent effects disappear, borders/text separation strengthen, and all actions remain available without relaunch

### Requirement: Automatic reduced-motion path
The system SHALL derive render policy from macOS Reduce Motion and SHALL remove continuous ambient movement, parallax, blur animation, particles, morphing, and spring overshoot.

#### Scenario: Reduce Motion enabled
- **WHEN** Reduce Motion becomes active
- **THEN** state changes use immediate transitions or opacity transitions no longer than 150 milliseconds and timer correctness remains unchanged

### Requirement: Contrast and non-color differentiation
The system SHALL respond to Increase Contrast and Differentiate Without Color with stronger boundaries and redundant labels, icons, patterns, or shapes for every meaningful status.

#### Scenario: Increased contrast
- **WHEN** Increase Contrast is enabled
- **THEN** text/background separation, focus rings, progress boundaries, disabled states, and selected controls remain distinguishable at all supported appearances

#### Scenario: Differentiate Without Color
- **WHEN** Differentiate Without Color is enabled
- **THEN** no selection, timer phase, warning, or completion state depends on amber or any other color alone

### Requirement: Low-power and visibility policy
The system SHALL stop continuous ambient rendering when Low Power Mode is enabled, Reduce Motion is enabled, or all owning scenes are hidden.

#### Scenario: Hidden app with menu bar only
- **WHEN** the main window is hidden and the menu-bar surface is not animating an explicit transition
- **THEN** no display-link, shader, mesh, particle, or ambient animation loop remains active

#### Scenario: Low Power Mode
- **WHEN** Low Power Mode activates during focus
- **THEN** the system freezes decorative motion while preserving timer projection, input, notifications, and state transitions

### Requirement: Keyboard-complete operation
Every action in initiation, focus, check-in, break, re-entry, review, settings, menu bar, and compact surfaces SHALL be reachable with Full Keyboard Access and SHALL display a visible focus state.

#### Scenario: Pointer-free focus loop
- **WHEN** the user completes the core loop using only keyboard input
- **THEN** every action is reachable in a logical order with no hover-only or pointer-only control

### Requirement: VoiceOver-semantic operation
The system SHALL expose headings, selection state, control purpose, task/action text, timer status, charts, and meaningful state transitions to VoiceOver without announcing countdown ticks every second.

#### Scenario: Screen transition
- **WHEN** the app moves from initiation to focus or from focus to check-in/break/review
- **THEN** VoiceOver focus moves to a focusable heading or one concise screen-state announcement is issued

#### Scenario: Timer accessibility value
- **WHEN** VoiceOver focuses the timer instrument
- **THEN** it receives the current phase, rounded meaningful remaining time, and paused/running state as one value without a per-second live-region announcement

#### Scenario: Energy/history chart
- **WHEN** a chart is focused with VoiceOver
- **THEN** the system exposes a title, ordered values, time context, and equivalent textual summary

### Requirement: Resizable and appearance-aware layout
The app SHALL support semantic dark and light appearances, large text, 200% content scaling where available, narrow resizable windows, zoom, and multiple display scales without clipping required controls.

#### Scenario: Narrow window with large text
- **WHEN** the main window is narrowed to its documented minimum while accessibility text sizing is active
- **THEN** primary task, timer, and escape actions remain visible or reachable by scrolling without overlap

#### Scenario: Appearance change
- **WHEN** macOS appearance changes during a session
- **THEN** semantic Liquid Instrument tokens update without losing focus, session state, or readable contrast

### Requirement: One hierarchy across native surfaces
The full window, menu-bar popover, and compact surface SHALL share task, phase, timer, and primary-action semantics while adapting density to available space.

#### Scenario: Menu-bar parity
- **WHEN** a session is active and the main window is closed
- **THEN** the menu-bar surface shows task orientation, phase/time, primary pause/resume, check-in/break escape, and a route back to the full window

#### Scenario: Compact surface
- **WHEN** the optional compact surface is enabled
- **THEN** it renders only canonical status and core commands and does not create an independent scene timer or hidden state

### Requirement: Visual evidence and regression policy
The native design SHALL preserve the Hallmark hierarchy and emotional direction without requiring pixel equality to browser blur radii, fixed dimensions, dark-only styling, or web typography.

#### Scenario: Visual regression review
- **WHEN** a core surface changes
- **THEN** visual review compares hierarchy, affordance, focus dominance, material roles, accessibility paths, and motion policy against the approved dossier rather than raw CSS pixel matching
