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
- **WHEN** the actual menu-bar popover, focus capsule, and return overlay are rasterized from fixed content under standard and increased `colorSchemeContrast`
- **THEN** the primary-text pixels measured on every named surface SHALL match the corresponding `SurfacePalette` branch, SHALL reach at least 4.5:1 under standard settings, and SHALL be strictly greater and at least 7:1 under increased contrast

## ADDED Requirements

### Requirement: Capability provenance without gated behavior
Every surface SHALL consult the internal capability-provenance registry where its feature key is constructed, and every surface and behavior in this spec SHALL remain available in the one product with no upsell or tier branch.

#### Scenario: The whole loop ships to everyone
- **WHEN** the app runs under its sole product configuration
- **THEN** all five main surfaces and all behaviors in this spec SHALL be available with no edition, tier, or upsell copy

## REMOVED Requirements

### Requirement: Edition gating seam without gated behavior
**Reason**: Owner issue #34 removed edition semantics from the product, so the old edition-specific requirement and scenario cannot remain canonical.
**Migration**: Use `Capability provenance without gated behavior`; each construction site still consults its feature key, the sole product configuration includes every behavior, hostile omission fails validation, and runtime lookup cannot withhold behavior.
