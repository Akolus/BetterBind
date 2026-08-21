# BetterBind

BetterBind is a unified World of Warcraft keybinding and macro manager. The
addon contains two integrated modules:

- **BetterMacro** — extended, profile-aware macro storage and editing.
- **Icon Browser** — a searchable, paged icon picker with a fixed 10×10 grid.

BetterBind is intended for modern WoW Retail. Version 1.0.4 preserves the
existing `BindPadVars`, `MegaMacroConfig`, `MegaMacroGlobalData`, and
`MegaMacroCharacterData` table formats used by the development builds.

## Features

### BetterBind

- 8×7 visible binding grid with additional slots in 40-slot increments.
- General and four character-specific tabs.
- Five specialization profiles.
- Drag-and-drop spells, items, mounts, toys, and macros into binding slots.
- Right-click BetterMacro icons to edit them in Icon Browser.
- Optional hotkey labels and automatic key saving.
- Locate a selected BetterMacro and scroll its BetterBind slot into view.

### BetterMacro

- 12×4 visible grid with additional pages.
- Global, class, specialization, character, and inactive scopes.
- Extended macro editor with syntax coloring and dynamic icon evaluation.
- Stable macro IDs so action bars and BetterBind slots retain their targets.
- Search and locate tools shared with BetterBind.

### Icon Browser

- Fixed 10×10 grid of 41×41 icons.
- Search by icon name, spell name, spell ID, or texture ID where available.
- Mouse-wheel paging that always keeps a complete icon page visible.
- Selected-icon highlight and fallback-icon support.

## Commands

| Command | Action |
| --- | --- |
| `/bb`, `/betterbind` | Open BetterBind and BetterMacro together |
| `/bbmm` | Open both windows explicitly |
| `/bm`, `/bettermacro`, `/m`, `/macro` | Open BetterMacro |
| `/bbfind` | Search BetterMacro and BetterBind slots |
| `/bbwhere` | Report where the selected BetterMacro is used |

Hold **Shift** and use the mouse wheel over either window header to change that
window's scale. Each scale is saved independently.

## Installation

1. Exit World of Warcraft.
2. Back up the account's `WTF` folder.
3. Extract the release so the manifest is located at
   `_retail_/Interface/AddOns/BetterBind/BetterBind.toc`.
4. Remove or disable the old custom `BindPad` folder before enabling
   `BetterBind`; loading both copies will create duplicate globals.
5. Start WoW and enable BetterBind in the AddOns list.

## Upgrading from the development build

Renaming the addon folder changes the SavedVariables filename used by WoW. To
carry the existing development data into the final addon, copy the old
`BindPad.lua` and `BindPad.lua.bak` files to `BetterBind.lua` and
`BetterBind.lua.bak` in every relevant `WTF/Account/.../SavedVariables/`
directory **while the game is fully closed**. Keep the originals until the new
installation has been verified.

The Lua table names inside those files intentionally remain unchanged, so no
data conversion is required after the file copy.

## Data warning

BetterMacro manages Blizzard's native macro slots to provide its expanded
scope system. Back up the account's `WTF` folder before installing, upgrading,
or removing the addon. Removing BetterBind without restoring a backup may leave
native stub macros behind.

## Project structure

```text
BetterBind/
├── Core/                    BetterBind binding engine and controller
├── Modules/
│   ├── BetterMacro/         extended macro module
│   └── IconBrowser/         icon search and selection module
├── UI/                      shared layout and media
└── Compatibility/           legacy API/UI compatibility layer
```

See [CHANGELOG.md](CHANGELOG.md) for release notes and
[ATTRIBUTION.md](ATTRIBUTION.md) for upstream credits and rights information.

## Source

<https://github.com/Akolus/BetterBind>
