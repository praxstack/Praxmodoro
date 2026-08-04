# focus-loop-ui

M1 proved the accessibility alternates structurally — by scanning sources and by asserting the physics engine is absent. That is necessary but not sufficient: it cannot see what actually renders. This change raises the transparency and contrast alternates to render-level proof and extends the keyboard scenario from a coverage map to real key events across the whole loop.

## MODIFIED Requirements

### Requirement: Complete accessibility alternates
Every surface SHALL provide full alternates: Reduce Motion or "Motion: still" SHALL stop the physics engine entirely and present a calm static field; Reduce Transparency SHALL replace translucent veils with solid semantic backgrounds, verified by rasterizing the surface background over a known backdrop; Increase Contrast SHALL meet contrast ratios on every text and control, verified by measuring rasterized foreground and background tokens; every control SHALL be keyboard-reachable and VoiceOver-labeled, and the whole loop SHALL be operable by real key events with no pointer input.

#### Scenario: Reduce Motion standdown is total
- **WHEN** system Reduce Motion is on or the user selects "Motion: still"
- **THEN** the physics engine SHALL not run, the field SHALL render its static alternate, and no continuous animation SHALL play anywhere

#### Scenario: Full keyboard loop
- **WHEN** a user operates only the keyboard
- **THEN** begin, hold/resume, check-in entry, check-in answers, break choices, break end, thought parking, and surface navigation SHALL all be reachable and visibly focused

#### Scenario: Keyboard loop as real key events
- **WHEN** an automated interface test drives begin, check-in entry, each check-in answer, break end, and new session using only key events
- **THEN** each key event SHALL advance the loop to the expected surface with no pointer interaction required

#### Scenario: VoiceOver on the field
- **WHEN** VoiceOver focuses the companion field region
- **THEN** it SHALL read a concise state description (e.g. "Companion: breathing, 17 minutes remaining") and the decorative layers SHALL be hidden from the accessibility tree

#### Scenario: Reduce Transparency verified at render level
- **WHEN** a surface background is rasterized with Reduce Transparency on, composited over a known backdrop color
- **THEN** the sampled rendered pixels SHALL show no trace of the backdrop, and the same background rasterized with Reduce Transparency off SHALL differ from it

#### Scenario: Increase Contrast verified at render level
- **WHEN** the surface text and background tokens are rasterized under standard and under increased contrast
- **THEN** the contrast ratio measured from the rendered pixels SHALL be at least 4.5:1 under standard settings and strictly greater under increased contrast
