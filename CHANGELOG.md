# Changelog

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
