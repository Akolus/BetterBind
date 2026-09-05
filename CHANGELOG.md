# Changelog

## 1.0.65 — 2026-08-24

- Makes a normal left-click on a populated BetterBind icon both open its
  keybind window and visibly select that icon.
- Connects BetterBind's existing internal `selectedSlotButton` state to the
  shared purple selected-cell texture, without changing binding or slot data.
- Refreshes both the previously selected icon and the newly selected icon, and
  clears the visual selection when switching BetterBind tabs or profiles.
- Preserves Shift+drag, cursor drops, right-click editing, icon-name styling,
  and all BetterMacro editor behavior.

## 1.0.64 — 2026-08-24

- Improves BetterBind and BetterMacro icon-name readability with fully opaque
  white text, a size increase from 9 to 10, and a consistent thin black
  outline over bright icon artwork.
- Retains the requested black shadow property at an exact `0, 0` offset; the
  thin outline makes its centered dark edge visibly useful instead of hiding
  completely beneath the foreground glyph.
- Limits the outline to icon names so macro-editor font metrics, scale-aware
  caret placement, navigation, and selection remain unchanged.

## 1.0.63 — 2026-08-24

- Adds a thin black shadow to every BetterBind, BetterMacro, and Icon Browser
  FontString with an exact `0, 0` shadow offset.
- Applies the same shadow to the macro editor's native input, syntax display,
  scale-aware measurement surface, and character counter without altering
  their font size or geometry.
- Replaces the remaining custom `1, -1` shadows with the new consistent style.
- Preserves scale-aware caret placement, Up/Down navigation, selection, and
  blinking.

## 1.0.62 — 2026-08-24

- Makes text-width and line-height measurement inherit BetterMacro's effective
  window scale, fixing horizontal and vertical caret drift below and above
  100% scale.
- Replaces the full one-physical-pixel X clearance with a half-pixel snap bias,
  keeping the caret clear of the preceding glyph without placing it too far to
  the right at 100% or larger scales.
- Extends diagnostics with the raw measured X coordinate and effective scales
  for the editor, syntax text, measurement text, and caret.
- Preserves Up/Down navigation, Shift-selection, mouse selection, and blinking.

## 1.0.61 — 2026-08-24

- Adds one physical pixel of clearance after the measured Open Sans glyph edge
  so the caret no longer merges with the last antialiased character (such as
  turning a final `s` into a `$`-like shape).
- Leaves the native-caret mask, mouse hit-testing, Up/Down navigation,
  Shift-selection, blinking, and vertical placement unchanged.

## 1.0.60 — 2026-08-24

- Adds explicit Up/Down arrow navigation between rendered visual lines in the
  macro editor, including wrapped lines.
- Preserves the caret's measured Open Sans horizontal column across consecutive
  vertical moves and restores that column after passing through shorter lines.
- Supports Shift+Up/Down selection while preserving the working mouse
  selection, caret blinking, focus restoration, and measured X/Y placement.
- Adds an optional `KEY` diagnostics entry for vertical navigation.

## 1.0.59 — 2026-08-24

- Positions the visible caret at the measured Open Sans glyph boundary instead
  of the center of WoW's native cursor rectangle, so end-of-line clicks place
  it after the last letter rather than through that letter.
- Keeps the complete native caret masked at its own coordinates while
  preserving the corrected measured Y position, blinking, focus restoration,
  mouse selection, and click-to-line mapping.
- Reports the measured horizontal boundary as the visual caret X coordinate in
  diagnostics.

## 1.0.58 — 2026-08-24

- Centers the one-pixel themed caret within WoW's reported two-pixel native
  cursor rectangle, placing it at the actual insertion gap instead of on the
  next letter.
- Separates native-caret masking geometry from the visible caret geometry: the
  native block is still fully covered at its reported position, while the
  themed caret uses the exact measured Open Sans row top and 14 px height.
- Fixes the reported vertical offset of roughly five pixels without changing
  selection, click mapping, focus restoration, or blink timing.
- Extends diagnostics to show native and visible caret coordinates separately.

## 1.0.57 — 2026-08-24

- Restores persistent EditBox focus after transparent-proxy clicks; the focus
  repair now runs specifically when the proxy has cleared focus and repeats
  after the short mouse-up settle window, restoring caret blinking.
- Positions the themed caret from WoW's exact `OnCursorChanged` rectangle
  instead of a separately measured text width.
- Masks the complete native caret rectangle and places the one-pixel themed
  caret on its right boundary, preventing it from crossing a letter.
- Forces a fresh native cursor rectangle when clicking the current cursor
  offset or after editing text, without changing the requested byte position.
- Adds focused caret state and native cursor-rectangle details to diagnostics.

## 1.0.56 — 2026-08-24

- Stops WoW's native mouse gesture and BetterBind's measured gesture from
  acting on the macro EditBox simultaneously; a transparent input proxy now
  provides one authoritative click, drag, double-click, and wheel path.
- Measures Open Sans' real rendered two-line advance instead of treating the
  requested font size as row height, fixing accumulated vertical row drift.
- Applies the bundled 14 px font directly and identically to the EditBox,
  syntax surface, native text region, and measurement surface.
- Cleans the short trailing duplicate fragment produced by the old competing
  drag paths (such as the reported `Drums` / `ums`) when the macro is opened or
  saved, while leaving valid commands and comments untouched.
- Reduces the syntax surface to the measured visual content height instead of
  thousands of pixels and expands diagnostics with line and metric details.

## 1.0.55 — 2026-08-24

- Restores the measured mouse handlers removed in 1.0.54, fixing the caret
  being locked and restoring live click-drag text selection.
- Retains 1.0.54's shared Open Sans FontObject, zero line spacing, focused
  syntax colours, safe syntax height, background, and custom blinking caret.
- Re-enables Shift+Arrow range tracking and release polling when a drag ends
  outside the editor, without adding another mouse-enabled text surface.

## 1.0.54 — 2026-08-24

- Restores syntax colours while the macro editor is focused.
- Uses one dedicated Open Sans FontObject for native selection, syntax text,
  caret measurement, and glyph layout to avoid sizing inconsistencies.
- Removes added line spacing and all custom mouse coordinate overrides; WoW's
  EditBox now owns click placement, drag selection, and double-click selection.
- Uses native cursor Y geometry for the custom blinking caret and gives syntax
  text a content-safe height so it cannot collapse remaining lines into `...`.

## 1.0.53 — 2026-08-24

- Replaces the layered focused-selection display with one native EditBox
  renderer: native Open Sans glyphs and native selection now share geometry.
- Keeps the established custom blinking caret and precise mouse positioning.
- Shows syntax colouring when the editor is unfocused and native plain text
  while editing, selecting, copying, cutting, or replacing text.
- Removes a trailing standalone `...` line from loaded and saved macro code.

## 1.0.52 — 2026-08-24

- Removes the visible `...` overflow marker; it was generated by a constrained
  syntax FontString and was never part of the saved macro.
- Makes the syntax display unlimited-line and sizes it from the same measured
  visual-line count used by selection, wrapping, scrolling, and caret geometry.
- Adds layout dimensions to `/bbedebug status` for targeted verification while
  preserving the working input, font, background, and caret paths.

## 1.0.51 — 2026-08-24

- Fixes the measured selection rectangles being drawn over the coloured macro
  glyphs, which made selected text look clipped or only partly highlighted.
- Places the non-interactive syntax FontString on the EditBox overlay: the
  selection now renders behind readable text and the caret remains above both.
- Keeps the confirmed selection range, Open Sans metrics, mouse handling,
  keyboard selection, background, and blinking caret unchanged.

## 1.0.50 — 2026-08-24

- Fixes multi-line selection backgrounds ending before the selected Open Sans
  text even though the underlying EditBox range was correct.
- Keeps WoW's native selection internally for copy, cut, replacement, and
  keyboard editing, but makes its mismatched background transparent.
- Draws one visible selection range using the same font measurements as the
  syntax text, including live drag, double-click, and Shift+Arrow selection.
- Preserves the 1.0.49 font, background, caret, and mouse-position logic.

## 1.0.49 — 2026-08-24

- Rebuilt from the known-good 1.0.46 caret and selection implementation.
- Fixes the invalid `C_Timer.After` callback introduced by the 1.0.48 global
  font hook. The font module no longer hooks or replaces any layout function.
- Bundles the supplied Open Sans Light face and applies it only to BetterBind
  frame trees. Existing sizes are preserved, while the macro editor is 14 px.
- Retains the proven custom caret; its position is measured from the bundled
  font after the editor layout completes normally.

## 1.0.46 — 2026-08-24

- Removed the redundant custom selection background now that the native
  EditBox highlight is confirmed to work for drag and double-click selection.
- Selection is drawn exactly once while preserving the fixed drag anchor,
  double-click word selection, caret, click placement, and syntax colours.

## 1.0.45 — 2026-08-24

- Fixed mouse selection collapsing to the release position when another editor
  callback cleared the transient drag state between mouse-down and mouse-up.
- Keeps the original mouse-down byte offset in an independent gesture anchor,
  restores live selection tracking after an external reset, and completes the
  gesture from the update loop if the normal mouse-up callback is skipped.
- Preserves the 1.0.41 caret geometry, precise click placement, blink timing,
  and syntax colours without modifying the caret implementation.

## 1.0.44 diagnostic — 2026-08-24

- Preserves the working caret, click placement, syntax colours, and existing
  selection implementation unchanged while instrumenting one mouse gesture.
- Adds `/bbedebug on`, `/bbedebug status`, and `/bbedebug off` to report
  mouse-down/up delivery, live drag-offset changes, selection applications,
  the tracked byte range, visible highlight regions, focus, and missed release.

## 1.0.43 — 2026-08-24

- Preserved the working 1.0.41 caret implementation and the 1.0.42 measured
  drag offsets without modifying either path.
- Moved only the click-drag selection mirror from the lower syntax surface to
  the EditBox's non-interactive artwork layer, making the tracked range visible
  above the coloured macro text.
- Continues applying the same range to the real EditBox selection for copying,
  replacement typing, and keyboard extension.

## 1.0.42 — 2026-08-24

- Preserved the 1.0.41 caret implementation without changing its position,
  one-pixel geometry, click placement, or half-second blink timer.
- Left-button dragging now applies the existing measured anchor and cursor
  offsets directly to the EditBox's real highlighted range.
- Mirrors drag selection from the editor's update path as a fallback when the
  parent ScrollFrame does not deliver its polling callback.

## 1.0.41 — 2026-08-24

- Restored syntax colours while the macro editor has focus instead of swapping
  to an uncoloured native text surface.
- Restored the dedicated half-second blinking caret; unchanged cursor callbacks
  no longer reset its blink timer, and its width is snapped to one screen pixel.
- Restored measured left-button drag selection with a visible range mirror, so
  selection no longer depends on the client's missing native highlight.
- Keeps the native EditBox as the keyboard target while explicitly blocking
  mouse propagation to the BetterMacro window and permanently retiring both
  legacy full-editor blocker frames.

## 1.0.40 — 2026-08-24

- Restored the original XML-created multiline macro `EditBox` so Blizzard owns
  its caret, focus, click placement, and drag-selection behavior end to end.
- Removed direct writes to the EditBox's internal `FontString`; presentation
  changes now use only the EditBox API so the native caret can blink normally.
- Stopped left-clicks and mouse motion in the editor from propagating to the
  parent window, and restricted BetterMacro window dragging to its title bar.
- Removed the whole-window left-drag registration that was stealing the same
  gesture required for selecting macro text.

## 1.0.39 — 2026-08-24

- Restored Blizzard's native macro text surface whenever the editor has focus,
  so the caret blinks normally and left-click dragging shows a live selection.
- Hides the syntax-colour display copy while editing and restores it after the
  field loses focus, preventing a second text/caret line from appearing.
- Replaced the fresh editor's single-line input template with a plain native
  multi-line `EditBox`, removing the stray parallel template artwork.

## 1.0.37 — 2026-08-23

- Restored macro syntax colours using a `FontString` region on the EditBox's
  `BACKGROUND` layer; unlike the retired child frame, the region has no mouse
  hit box and cannot block focus or dragging.
- Keeps the EditBox's internal text/caret colour opaque while hiding only its
  native glyph region, preserving Blizzard's caret above the coloured text.
- Added a minimal left-drag bridge that highlights the exact byte-offset range
  already reported by the native EditBox; it performs no glyph measurement,
  creates no selection textures, and never calls `SetCursorPosition()`.

## 1.0.36 — 2026-08-23

- Removed the remaining syntax-display frame completely so no child surface can
  cover or intercept the real BetterMacro EditBox before it gains focus.
- Permanently retired the legacy full-size `MegaMacro_FrameTextButton` and
  formatted-editor layers that were still positioned over the raw editor.
- Keeps the native EditBox text layer fully visible at all times, restores its
  full hit rectangle, and explicitly enables it whenever a macro is selected;
  Blizzard now owns focus, caret rendering, and drag selection end to end.

## 1.0.35 — 2026-08-23

- Removed the standalone `/bbb` diagnostic editor, its saved-variable entry,
  and its complete runtime module.
- Removed all remaining custom macro-selection measurement, polling, cursor,
  highlight-overlay, and mouse-handler code from BetterMacro.
- While focused, the macro field now shows the real Blizzard EditBox text layer
  so Blizzard renders its own caret and left-drag selection without an overlay;
  syntax colours return when the field loses focus.

## 1.0.34 — 2026-08-23

- Removed BetterMacro's custom caret, native-caret mask, positioning arithmetic,
  pixel snapping, and custom blink cycle completely.
- Restored Blizzard's native EditBox caret without changing its coordinates,
  dimensions, or blink behavior; syntax colours, selection, scrolling, and the
  character counter remain unchanged.

## 1.0.33 — 2026-08-23

- Rebuilt left-button macro selection around the EditBox's own cursor byte
  offsets: the drag path never estimates glyph widths and never calls
  `SetCursorPosition()` while the mouse is held.
- Added live native-range highlighting during left-drag and preserved the same
  exact range after mouse-up without replacing the cursor offset.
- Moved the themed caret to the right edge of WoW's native caret rectangle and
  masks the full native rectangle, preventing the replacement caret from
  overlapping the preceding glyph.

## 1.0.32 — 2026-08-23

- Restored native left-click, click-drag, and double-click ownership to the
  macro EditBox; custom polling no longer collapses the selection by calling
  `SetCursorPosition()` every frame while the mouse button is held.
- Removed estimated left-click offsets and the deferred mouse-up reassertion
  that could move an end-of-macro click several characters backwards.
- Made the one-physical-pixel themed caret follow the exact coordinates from
  `OnCursorChanged`, eliminating the cumulative horizontal drift caused by
  re-measuring proportional-font prefixes after every arrow-key movement.

## 1.0.31 — 2026-08-23

- Fixed the macro caret intermittently rasterizing at two physical pixels by
  replacing its one-UI-unit width with an exact one-screen-pixel calculation.
- Snapped the caret and its native-caret mask to WoW's physical pixel grid so
  fractional UI scaling cannot make the caret overlap a neighbouring glyph.

## 1.0.30 — 2026-08-23

- Fixed the custom macro caret remaining one glyph behind after typing by
  deriving its rendered position from the current text and logical cursor
  offset instead of the callback's occasionally stale pre-insert geometry.
- Kept mouse placement row-specific while giving keyboard movement and typing
  a shared visual-offset calculator, so the caret sits between characters and
  rests beyond the final glyph at the end of a line.

## 1.0.29 — 2026-08-23

- Made the mouse's measured row and glyph boundary authoritative for macro
  clicks and click-drag selection instead of trusting the client-dependent
  native cursor value that could remain stuck at the end of the macro.
- Reasserted a clicked cursor position after native mouse-up processing so the
  insertion point cannot snap back to the final line on the following frame.
- Moved the custom caret and native-caret mask onto the EditBox overlay layer,
  where they can cover WoW's stale caret without adding a mouse-blocking frame.
- Matched caret height and top alignment to the editor's 14-pixel visual rows,
  preventing the insertion point from appearing between adjacent lines.

## 1.0.28 — 2026-08-23

- Removed BetterBind's remaining green slot glow at its source: both legacy
  slot refresh implementations now keep the old `UI-ActionButton-Border`
  hidden for every slot type, with a final guard in the shared BB cell skin.
- Kept macro syntax colours visible while the command editor is focused by
  leaving the mouse-disabled syntax surface active and making only the native
  EditBox glyphs transparent.
- Reconnected the existing one-pixel blinking caret to `OnCursorChanged` and
  `OnUpdate`, restoring a visible caret at the clicked text position.
- Reconnected left-click, click-drag, double-click, and deferred selection
  tracking to the native EditBox while preserving keyboard input and scrolling.
- Added a live `used / 250` character counter to the lower-right corner of the
  macro command window and reserved editor padding so text cannot overlap it.

## 1.0.27 — 2026-08-23

- Fixed the 1.0.26 startup regression caused by five hover textures being
  created at sublevel `8`; WoW only accepts texture sublevels from `-8` to `7`.
  The invalid call stopped BetterBind's lower layout before BetterMacro,
  keybinding, legacy-art cleanup, and title controls could be applied.
- Corrected every affected underline to the API-safe maximum sublevel `7` and
  audited every explicit texture sublevel in the addon.
- Removed client-dependent `SetNormalTexture(nil)`, `SetPushedTexture(nil)`,
  `SetHighlightTexture(nil)`, and `SetDisabledTexture(nil)` calls from close
  controls; existing button regions are now hidden without replacing them.
- Isolated PLAYER_LOGIN handlers, main layout phases, Icon Browser layout, and
  each close-marker pass so a cosmetic failure is reported without preventing
  the remaining interface from loading.

## 1.0.26 — 2026-08-23

- Replaced every title-bar close texture with a borderless font-rendered `X`
  attached directly to the working close button, including BetterBind,
  BetterMacro, Icon Browser, and the keybinding dialog.
- Unified all visible toggles as 20-pixel controls with a solid cyan square for
  the checked state.
- Rebuilt the keybinding dialog on an opaque neutral surface, reduced its width
  to 520 pixels, and added a draggable 34-pixel title area with saved position.
- Consolidated tabs, action buttons, plus/minus controls, and search inputs on
  the same one-pixel border and restrained teal hover treatment.
- Removed the green BetterBind macro-slot accent and forced the shared
  Plunderstorm cell background to a neutral desaturated tint.
- Darkened empty icon cells using their existing texture layer so unused slots
  stay distinct without adding another overlay.
- Removed the unreferenced BetterMacro 12.1 compatibility shim after verifying
  that no remaining module calls its retired icon-array helper.

## 1.0.25 — 2026-08-23

- Fixed missing BetterBind and Icon Browser close marks and retired Blizzard
  red X textures by moving the modern close artwork to a reliable 32-bit TGA
  attached directly to each close button's overlay layer.
- Reasserted the shared close style after main-window, dialog, and tab layout
  refreshes so Blizzard templates cannot restore their original artwork.
- Restored the keybinding dialog's earlier neutral solid background while
  retaining its one-pixel border and native live key text.
- Darkened and subdued the supplied circuit artwork, then reduced its window
  opacity so it no longer competes with empty BetterBind/BetterMacro cells.
- Increased the existing empty-cell surface opacity without adding another
  overlay or backdrop frame.
- Removed the dark shade over populated icons by rendering the Cooldown
  Manager border additively and reducing Plunderstorm backdrop bleed-through.

## 1.0.24 — 2026-08-22

- Fixed Icon Browser layout stopping at the close-button pass; the browser now
  completes its compact header, search, 10×10 grid, and Apply/Cancel layout.
- Replaced every title-bar close mark with a transparent modern PNG icon and a
  restrained violet hover border, avoiding client-dependent rotated textures.
- Kept BetterMacro's full-window visual shell separate from its transparent
  drag header so the background can no longer be collapsed to title-bar size.
- Reworked the supplied routing-line artwork into a 90°-rotated charcoal
  background with thinner steel, teal, and violet details for BetterBind,
  BetterMacro, Icon Browser, and the keybinding dialog.
- Applied the HUI icon stack and full interaction scripts to every lazily
  created BetterMacro slot, including rows revealed by the plus control.
- Removed the obsolete Stage 8 lazy-slot callback and refreshed new slots
  through the consolidated appearance layer.
- Pinned macro command text to a readable 12-pixel font while retaining WoW's
  native caret placement, selection, keyboard input, and idle syntax colours.

## 1.0.23 — 2026-08-22

- Fixed HUI icon clipping by creating each `MaskTexture` from its owning button
  and attaching it to the spell texture; enlarged icons no longer remain
  visible as squares outside the 0.96 mask.
- Added a recoloured charcoal circuit background to BetterBind, BetterMacro,
  Icon Browser, and the keybinding dialog using one art region per window.
- Replaced font-based title-bar close glyphs, which rendered as `4` on some
  clients, with two crisp one-pixel texture strokes and a purple hover state.
- Restyled scope tabs and common controls with consistent one-pixel borders,
  a restrained selected state, and subtle teal hover feedback.
- Restored native macro-editor caret placement and drag selection by moving the
  display-only syntax surface below the EditBox and hiding it while editing.
- Removed the BetterMacro editor's runtime custom caret and mirrored-selection
  overlays; syntax colours return when the editor loses focus.
- Kept the BetterMacro shell full-size and explicitly mouse-passive so its new
  background stays visible without interfering with text input.

## 1.0.22 — 2026-08-22

- Consolidated thirteen incremental compatibility/layout Lua files into the
  single purpose-named `UI/Interface.lua` runtime layer.
- Removed the three retired settings-window implementations and superseded
  visual passes that created hidden duplicate frames, borders, and textures.
- Replaced per-frame drag polling with `CURSOR_CHANGED` feedback and native
  drag callbacks; the consolidated interface has no `OnUpdate` handler.
- Reduced each scope tab from a fill plus four border textures to one reusable
  backdrop surface, one underline, and one gradient.
- Removed the keybinding dialog's duplicate backdrop and text overlay, styling
  its native live text regions directly so action and key labels stay visible.
- Made selection and search highlights allocate only for actual matches instead
  of pre-creating an overlay for every BetterBind slot.
- Replaced the stacked legacy cell passes with one controlled icon stack per
  BetterBind/BetterMacro slot and one shell per window.
- Removed the BetterBind and BetterMacro main-window Exit buttons; both windows
  continue to use their compact title-bar close controls.
- Replaced inherited Blizzard slot, pressed, hover, and selected artwork with a
  low-alpha unified icon surface, removing unused textures from XML templates.
- Applied subtle rounded masking to every icon presentation while retaining
  independent full/cropped artwork controls and migrating the retired round-only
  setting to cropped artwork.
- Aligned hover, selection, linked-macro, search-match, and locate-pulse borders
  to the icon tile edge instead of expanding them two to four pixels outside it.
- Replaced the simple rounded-square treatment with the requested HUI-style
  stack: Plunderstorm backdrop, Cooldown Manager border, HUI Cooldown Manager
  mask at 0.96 scale, and spell artwork at 1.13 scale.
- Replaced square selection/search/locate backdrop frames with atlas-shaped
  texture regions; selected icons now use a purple, desaturated Professions
  Gear Enchant effect.

## 1.0.21 — 2026-08-22

- Fixed coloured macro text appearing almost black because the syntax region
  was rendered beneath BetterMacro's EditBox frame.
- Moved syntax text, selection shading, and the themed caret onto a dedicated
  higher-level visual surface so all editor colours render at full brightness.
- Explicitly disabled mouse clicks and mouse motion on the visual surface,
  leaving the native EditBox as the only input target.
- Preserved the 1.0.20 click-position fallback, drag selection, double-click
  word selection, mouse-wheel scrolling, and corrected caret blink timer.

## 1.0.20 — 2026-08-22

- Replaced the active tab's stacked glow strips with one continuous vertical
  purple gradient, eliminating the visible horizontal seams.
- Moved the coloured macro syntax FontString off the EditBox and onto the
  non-interactive scroll viewport so it cannot disturb native mouse input.
- Added measured click placement as a fallback when WoW does not publish a new
  native cursor position, preventing the caret from remaining at the end.
- Extended the same fallback across left-button dragging while retaining the
  real selected range after mouse-up.
- Fixed the themed caret blink timer being continually reset by repeated
  `OnCursorChanged` callbacks that reported an unchanged caret position.
- Added regression coverage for unchanged cursor callbacks and clients that do
  not move the native caret after a text click.

## 1.0.19 — 2026-08-22

- Removed the bright blue focus border from the BetterMacro text editor.
- Restored native left-button click-and-drag selection by keeping the EditBox
  as the only mouse target and tracking its live caret endpoint while held.
- Made the coloured syntax display a direct, non-interactive EditBox region so
  it cannot intercept native text selection.
- Added a visible selection mirror beneath the coloured syntax text while
  preserving WoW's real selected range for copy, replacement, and deletion.
- Retained mouse-up-based double-click word selection and reapplication so the
  selected word remains active after WoW finishes its native click handling.
- Replaced the blue selected-tab fill on BetterBind and BetterMacro scope tabs
  with a purple bottom underline and a soft purple glow fading upward.
- Prevented the legacy compatibility tab styler from restoring the old blue
  selected state after a tab change.

## 1.0.18 — 2026-08-22

- Fixed BetterMacro text becoming invisible whenever WoW's native selection
  highlight was drawn above the coloured syntax FontString.
- Moved the coloured text and themed caret onto a higher-level, mouse-disabled
  child surface so text remains readable both normally and while selected.
- Kept the real EditBox beneath that surface as the only mouse and keyboard
  input target, preserving click placement, dragging, copying, and replacement.
- Made editor initialization fail-safe by creating and populating the visible
  syntax surface before making the native glyph and block-caret layer
  transparent.
- Applied the same rendering-order correction to the standalone `/bbb` editor.

## 1.0.17 — 2026-08-22

- Ported the proven standalone `/bbb` input behavior into the real
  BetterMacro editor while preserving BetterMacro's save and macro-data flow.
- Added BetterMacro's live mouse-transparent syntax display for commands,
  conditions, targets, comments, invalid text, and separators.
- Added distinct validated colours for spell names, item names, and `/click`
  references, including spell arguments used by `/cancelaura`.
- Changed BetterMacro double-click recognition to use WoW's completed native
  mouse-up caret position, selecting the complete word under the cursor.
- Preserved native left-click placement and click-drag selection, retained
  right-button drag selection, and kept mouse-wheel scrolling.
- Hid BetterMacro's native block caret and replaced it with the thin blinking
  one-pixel, 20-pixel-tall themed caret proven in the standalone editor.
- Anchored Edit, Save, and Cancel as a horizontal row beneath the editor before
  editor setup, preventing legacy XML anchors from leaving them beside the
  selected macro when editor initialization is delayed or interrupted.

## 1.0.16 — 2026-08-22

- Moved standalone-editor double-click detection to the completed native
  mouse-up position so a double-click selects the word under WoW's real caret.
- Preserved the standalone editor's working native left-click placement and
  click-drag selection without adding an input-blocking interaction frame.
- Replaced the opaque native block caret with a one-pixel, 20-pixel-tall
  blinking themed caret while retaining native text editing underneath.
- Added an independent, mouse-transparent syntax-colour layer for commands,
  conditions, targets, comments, separators, invalid text, and command bodies.
- Added distinct validation colours for spell names and item names using WoW's
  current spell and item APIs, including refreshes when requested data loads.
- Added a separate reference colour for `/click` targets and a spell/item
  colour legend to the standalone editor status line.

## 1.0.15 — 2026-08-22

- Added a completely independent standalone macro editor opened with `/bbb`.
- Gave the diagnostic editor its own frame, scroll viewport, EditBox, caret,
  selection handlers, mouse-wheel handler, and automatically saved draft.
- Implemented same-frame-safe double-click word selection and polled
  right-button drag selection without calling any BetterMacro editor code.
- Positioned its one-pixel, 18-pixel-tall blinking caret directly from WoW's
  reported cursor coordinates without applying the text insets twice.
- Kept all diagnostic update work inactive while the `/bbb` window is hidden.

## 1.0.14 — 2026-08-22

- Fixed a same-frame timing bug where the second left click cancelled the
  deferred cursor callback for the first click, preventing double-click word
  selection from ever recognizing the pair.
- Moved held-button selection polling from the EditBox's native update handler
  to the visible scroll viewport so it cannot compete with Blizzard's caret and
  scrolling updates.
- Replaced the editor's short, wide stationary caret with a masked one-pixel,
  18-pixel-tall caret using a half-second blink interval.
- Kept selection polling inactive whenever the BetterMacro editor is hidden.

## 1.0.13 — 2026-08-22

- Used live in-game diagnostics to confirm that BetterMacro receives
  `LeftButton` events and accurate native cursor positions but receives no
  `RightButton` mouse-down event from WoW's EditBox.
- Changed left-button double-click selection to use the native cursor position
  after WoW completes its internal caret placement.
- Changed right-click dragging to detect the right-button state while the
  cursor is inside the editor instead of waiting for an event WoW never sends.
- Added a regression test that withholds the right-button event and verifies
  native-cursor word selection, polled right-drag selection, and wheel
  scrolling.

## 1.0.12 — 2026-08-21

- Used an in-game Frame Stack capture to identify an external
  `M33kAurasAttachToMouseFrame` at HIGH strata above BetterMacro's MEDIUM
  editor.
- Raised only the BetterMacro editor and its scroll viewport to DIALOG strata
  so higher-level mouse-follow frames cannot intercept text input.
- Left the external addon and every non-editor BetterBind frame unchanged.
- Added a runtime regression check for editor strata alongside the selection,
  opacity, and mouse-wheel checks.

## 1.0.11 — 2026-08-21

- Retired two legacy BetterMacro syntax-layer compatibility routines that
  reduced the native editor text region to 3% or 0% opacity.
- Restored the sole native editor region to full opacity whenever BM applies
  its layout.
- Added a non-interactive blue selection display behind selected characters
  while preserving the real EditBox selection for copying and replacement.
- Added runtime coverage that begins with the legacy 3% opacity state and
  verifies full text opacity, visible double-click selection, right-drag
  selection, and wheel scrolling.

## 1.0.10 — 2026-08-21

- Added explicit double-click word selection to the BetterMacro editor for
  both left and right mouse buttons.
- Added explicit right-click-and-drag text selection instead of relying on
  WoW's native left-button-only behavior.
- Kept selection offsets accurate across wrapped lines, explicit newlines, and
  UTF-8 macro text.
- Reapplied the native selection highlight after WoW finishes its internal
  mouse processing so the completed selection remains visible and editable.
- Added isolated runtime checks for double-click selection, right-button drag
  selection, and editor mouse-wheel scrolling.

## 1.0.9 — 2026-08-21

- Removed BetterMacro's obsolete formatted editor, full-size editor click
  button, and legacy editor background directly from the window XML.
- Reused BetterMacro's sole native EditBox instead of replacing it at runtime.
- Restricted BetterMacro's mouse-enabled drag shell to the 38-pixel title bar
  so it cannot cover the macro text area.
- Removed the unused formatted-text parsing pass that continued updating the
  deleted syntax layer.
- Kept native text selection as the only click handler and added direct wheel
  scrolling with recalculated long-text bounds.

## 1.0.8 — 2026-08-21

- Rebuilt the BetterMacro text editor from scratch as a single native WoW
  EditBox and ScrollFrame.
- Removed the syntax-colored display overlay, custom caret, selection math,
  and transparent input layer that could intercept editor mouse input.
- Restored native click placement, double-click word selection, and
  click-and-drag text selection.
- Added direct mouse-wheel handling to the visible editor and recalculated its
  scroll range from the native text height.

## 1.0.7 — 2026-08-21

- Routed BetterMacro editor mouse input through a dedicated interaction layer
  so the scroll and syntax-display layers cannot intercept selection gestures.
- Fixed double-click word selection and left/right click-and-drag selection
  persisting after the mouse button is released.
- Added mouse-wheel scrolling to the BetterMacro text editor.
- Recalculated the scroll-child bounds after editor height changes so long
  macros scroll through their full contents.

## 1.0.6 — 2026-08-21

- Fixed BetterMacro selections being hidden beneath the syntax-colored text
  layer.
- Made double-click word selection visibly highlight the selected word.
- Added click-and-drag selection with either the left or right mouse button.
- Preserved the completed selection when the mouse button is released outside
  the editor.

## 1.0.5 — 2026-08-21

- Added click-and-drag text selection to the BetterMacro editor.
- Added double-click word selection.
- Kept selection positions accurate across explicit and visually wrapped
  lines.
- Preserved complete UTF-8 character boundaries when selecting localized
  macro text.

## 1.0.4 — 2026-08-21

- Removed the obsolete BetterMacro Lock/Unlock button, including its initial
  login flash on fresh characters.
- Restyled the keybinding dialog to match BetterBind's flat dark theme.
- Replaced the Blizzard dialog border with a single rectangular background.
- Matched the Exit, Unbind, close, and For All Characters controls to the
  addon's existing button and checkbox styles.
- Restored the Keybinding, Press a Key to Bind, selected action, and Current
  Key text on a dedicated foreground layer so other UI frames cannot cover it.
- Anchored BetterMacro directly to BetterBind's right edge so both windows
  remain aligned when Blizzard moves BetterBind for the spellbook or another
  managed panel.

## 1.0.3 — 2026-08-20

- Added a bottom-left Delete button to the BetterBind window.
- Added confirmation before removing the selected BetterBind icon.
- Removed the deleted slot's key binding without deleting its underlying spell,
  item, native macro, or BetterMacro macro.
- Disabled deletion when no populated BetterBind slot is selected and prevented
  deletion during combat.

## 1.0.2 — 2026-08-20

- Suspended BetterMacro evaluation while every addon window is closed.
- Suspended linked-drag, release, cursor-feedback, and style watchers while
  their corresponding windows are closed.
- Preserved full per-frame updates while BetterBind, BetterMacro, or Icon
  Browser is open.

## 1.0.1 — 2026-08-18

- Fixed BetterMacro editor clicks always placing the caret at the end.
- Added font-aware click positioning for explicit and visually wrapped lines.
- Kept cursor offsets on valid UTF-8 character boundaries.

## 1.0.0 — 2026-08-18

- Renamed the addon and install folder to BetterBind.
- Organized BetterMacro and Icon Browser as first-class modules.
- Rebuilt the BetterBind and BetterMacro window controllers.
- Added 8×7 BetterBind and 12×4 BetterMacro visible grids.
- Added 40-slot paging for BetterBind and 48-slot paging for BetterMacro.
- Added the fixed 10×10, 41×41 Icon Browser with stable wheel paging.
- Added icon lookup by available names and numeric IDs.
- Added stable BetterMacro icon transfer into BetterBind slots.
- Added right-click editing and consistent button interactions.
- Added automatic scrolling when Locate targets an off-screen BetterBind slot.
- Added independent Shift+wheel window scaling.
- Preserved legacy SavedVariables table names and runtime APIs for profile,
  macro, and keybinding compatibility.
- Updated the retail interface metadata and release packaging layout.
