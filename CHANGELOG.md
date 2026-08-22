# Changelog

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
