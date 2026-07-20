# Findings

## Current Synthesis

No findings section yet.

## Strong Evidence

- None yet

## Weak Evidence Or Gaps

- None yet

## Contradictions

- None yet

## Next-Step Guidance

- Populate after the first merged wave


## Wave 1: w1-competitor-official

- [w1-competitor-official-001] The mature competitive baseline is no longer a timer alone: leading products combine flexible timing, task context, distraction blocking, history or analytics, automation, and cross-device behavior. (`supported`)
- [w1-competitor-official-002] RoundPie differentiates through breadth of inbound task integrations, outbound automation, time logs, interruption notes, and scripting rather than through a narrow Pomodoro experience. (`supported`)
- [w1-competitor-official-003] The strongest ADHD-specific competitor proposition is an execution loop: keep one task visible, interrupt time blindness with periodic check-ins, block detours, and reconstruct the day automatically in a timeline. (`supported`)
- [w1-competitor-official-004] Flexible session structures are a proven market pattern: fixed Pomodoro, open-ended Flowmodoro, preparation stages, user-defined multi-stage sessions, and reflection can coexist without forcing one timing doctrine. (`supported`)
- [w1-competitor-official-005] Praxodoro should treat planning, focusing, recovering, and reviewing as one session lifecycle, while keeping each stage skippable and progressively disclosed. (`supported`)

## Wave 1: w1-user-friction

- [w1-user-friction-001] Reminder delivery is not equivalent to task initiation: users describe receiving prompts from planning apps while remaining unable to begin, especially when the task is not already reduced to a concrete first action. (`supported`)
- [w1-user-friction-002] High-maintenance productivity systems create an abandonment risk for people who already struggle with planning consistency, input burden, and switching between tools. (`supported`)
- [w1-user-friction-003] Subscription pricing creates visible resentment in the Mac productivity market, especially when users perceive the core function as replaceable by a desk timer or paper. (`supported`)
- [w1-user-friction-004] The product should default to an immediate one-task start path, then reveal planning, analytics, blocking, and customization only when they are relevant or explicitly requested. (`supported`)

## Wave 1: w1-adhd-research

- [w1-adhd-research-001] For adults with ADHD, structured skills work around organization, planning, time management, distractibility, and adaptive thinking has stronger evidence than generic computerized attention training. (`supported`)
- [w1-adhd-research-002] Digital self-guided interventions can improve adult ADHD-related outcomes in trials, but product claims must disclose that evidence concerns structured therapeutic programs, not ordinary focus timers, and some studies involve developer conflicts of interest. (`supported`)
- [w1-adhd-research-003] Micro-breaks show a reliable small-to-moderate well-being benefit across studies, especially for vigor and fatigue, while aggregate performance benefits are less consistent and depend on task and break duration. (`supported`)
- [w1-adhd-research-004] There is no single universally superior break schedule: a 2023 study favored systematic short breaks over self-regulated breaks, while later comparisons found self-regulated breaks could preserve mood or motivation better than rigid Pomodoro schedules. (`disputed`)
- [w1-adhd-research-005] Praxodoro should make break guidance adaptive and user-steerable: offer fixed, flow-preserving, and recovery-first modes; learn from self-reported energy and return difficulty; never claim an objectively optimal cadence. (`supported`)
- [w1-adhd-research-006] An ADHD-aware coach should externalize the next action and progress state, use brief agenda/check-in loops, and avoid punitive streak loss or moralized productivity language. (`supported`)

## Wave 1: w1-macos-visual-tech

- [w1-macos-visual-tech-001] Apple positions Liquid Glass as a functional layer for controls and navigation above content, explicitly warning against using it throughout the content layer or on every custom surface. (`supported`)
- [w1-macos-visual-tech-002] A high-end native Mac implementation can combine system Liquid Glass, standard materials and vibrancy, responsive spring or morphing transitions, MeshGradient, and SwiftUI-accessible Metal shader effects without replacing the platform window or control model. (`supported`)
- [w1-macos-visual-tech-003] Accessibility requires complete alternate render paths: Reduce Transparency should replace translucent surfaces with solid semantic backgrounds, Reduce Motion should suppress depth/parallax and continuous effects, and increased contrast, keyboard access, and VoiceOver must remain first-class. (`supported`)
- [w1-macos-visual-tech-004] Third-party effect packages are best treated as optional, bounded tools: Pow offers transitions and value-change effects, Vortex offers cross-platform particles, Inferno provides inspectable SwiftUI Metal shader examples, and Glur specializes in progressive Metal blur. (`supported`)
- [w1-macos-visual-tech-005] The recommended visual architecture is advanced hybrid skeuomorphism: a living ambient content field, solid or standard-material instrument panels, refractive glass controls and navigation, tactile inset and raised surfaces, and rare particle or shader celebrations tied to meaningful state changes. (`supported`)

## Wave 2: w2-breaks-adhd-falsification

- [w2-breaks-adhd-falsification-001] Current evidence does not validate an algorithm that autonomously prescribes the optimal break cadence for an individual with ADHD. (`supported`)
- [w2-breaks-adhd-falsification-002] Body doubling and socially aware AI are promising design directions for task initiation, but their effectiveness evidence remains early, context-specific, and insufficient for outcome claims. (`supported`)
- [w2-breaks-adhd-falsification-003] Recent ADHD-centered HCI evidence supports a low-friction, nonjudgmental coach that offers task breakdown, proactive help at the right moment, multimodal cues, plan negotiation, and capacity-sensitive options rather than rigid enforcement. (`supported`)
- [w2-breaks-adhd-falsification-004] The safe product language is 'ADHD-aware focus coach' or 'designed with ADHD-related executive-function challenges in mind,' paired with explicit non-medical positioning and user control. (`supported`)

## Wave 2: w2-platform-feasibility

- [w2-platform-feasibility-001] SwiftData with CloudKit is suitable for local-first tasks, settings, session history, and summary state, but its managed sync is not a real-time countdown transport and commonly propagates changes on a roughly minute-scale natural cadence. (`supported`)
- [w2-platform-feasibility-002] Reliable system-wide network blocking on macOS requires Network Extension capabilities and, for broad direct distribution, a privileged system-extension deployment path; it materially increases signing, installation, support, and failure risk. (`supported`)
- [w2-platform-feasibility-003] EventKit can integrate Apple Calendar and Reminders on macOS, but the app must request only the access needed, explain it clearly, and treat denial as a fully supported state. (`supported`)
- [w2-platform-feasibility-004] On macOS, App Intents are available to the Shortcuts app even though predeclared App Shortcuts are not; Praxodoro can expose Start Focus, Pause, Complete, Log Distraction, and Open Check-in actions for user-built automations. (`supported`)
- [w2-platform-feasibility-005] Apple's Foundation Models framework can privately generate structured task-breakdown suggestions on-device, but eligibility, Apple Intelligence settings, model readiness, and model-version drift require a deterministic fallback and evaluation suite. (`supported`)

## Wave 2: w2-effects-dependency-audit

- [w2-effects-dependency-audit-001] Pow, Vortex, Inferno, and Glur are all MIT-licensed and declare macOS 12 or newer, but their maintenance and dependency profiles differ materially. (`supported`)
- [w2-effects-dependency-audit-002] Vortex, Inferno, and Glur declare no package dependencies, while Pow declares an exact SnapshotPreviews-iOS dependency even though its preview integration is disabled by default. (`supported`)
- [w2-effects-dependency-audit-003] None of the four audited repositories contains an integrated Reduce Motion or Reduce Transparency policy; Praxodoro must gate third-party effects at its own design-system boundary. (`supported`)
- [w2-effects-dependency-audit-004] The core UI should have zero mandatory visual-effect dependencies; prototype native SwiftUI and Metal first, then consider Vortex for rare particles or selectively port a small audited Inferno shader with attribution. (`supported`)

## Wave 2: w2-product-scope-adjudication

- [w2-product-scope-adjudication-001] The smallest differentiated product is not a smaller feature list; it is a complete low-friction loop: choose or capture one task, create a tiny first action, start, stay visibly oriented, check in gently, recover deliberately, and record what happened. (`supported`)
- [w2-product-scope-adjudication-002] Ship-first capabilities should be native timer modes, one-task initiation, flexible check-ins, intentional breaks, scratchpad/distraction capture, reflection, local analytics, menu-bar and floating views, keyboard commands, accessibility variants, and local-first persistence. (`supported`)
- [w2-product-scope-adjudication-003] Stage Calendar and Reminders import, CloudKit history sync, App Intents, richer analytics, deterministic workspace automations, and optional on-device task breakdown after the core loop proves usable. (`supported`)
- [w2-product-scope-adjudication-004] Keep system-wide blocking, live cross-device timer control, passive app or website surveillance, social body doubling, and physiological fatigue inference experimental until separate privacy, distribution, reliability, and efficacy gates are met. (`supported`)
- [w2-product-scope-adjudication-005] Reject punitive streak loss, forced breaks, mandatory account creation, configuration-heavy onboarding, manipulative urgency, diagnostic scoring, and productivity judgments based on app activity. (`supported`)
