# WoW Guild Online Widget

A small, modern World of Warcraft addon that shows how many guild members are online. The widget is manually movable/lockable and can be opened from Edit Mode via a shortcut in the widget menu. On hover, it shows a tooltip listing online members along with their **level** and **zone/location**. The tooltip list supports a **right-click context menu** for common actions (whisper, invite, target, etc.).

## Goals / UX
- **Tiny footprint**: a compact widget you can place anywhere.
- **Modern look**: minimal frame, readable typography.
- **Fast**: no heavy updates; event-driven with light throttling.
- **Safe**: uses Blizzard API only (no automation beyond what’s allowed).

## Current Features
- **Widget frame**
  - Displays `Online: N` (optional `Online: N/M`)
  - Manual move + saved position; lock/unlock
  - **Left-click** toggles the list (pin/unpin)
  - **Right-click** widget menu for settings (including a shortcut to enter Edit Mode)
- **Guild list (tooltip/popup)**
  - Hover preview: shows while you hover, hides when you leave
  - Pinned mode: stays open until you click again
  - Auto-flip positioning (near bottom opens upward; near right edge aligns right)
  - More readable **zone/location** column (wider + dynamic truncation)
  - Optional **Mythic+ score** column with Blizzard rarity colors
  - Sorting: name, level, zone
  - Low-frequency refresh while visible (helps keep zones up to date without spamming)
- **Member actions** (right-click a row)
  - Whisper
  - Invite
  - Target
  - Who

Menu API is defensive: tries modern Retail context menu API first, then falls back to `EasyMenu`/`UIDropDownMenu`.

## Non-goals (for v1)
- Cross-realm community roster support (unless needed)
- Persistent data storage beyond basic settings
- Heavy UI frameworks unless we decide to adopt Ace3 later

## Compatibility
- Target: **Retail**.
- TOC Interface currently set to `120001` (12.0.1 series). Bump this on major/minor Retail patches as needed.
- Classic support can be added later with a different anchoring strategy.

## Development Notes
This addon will primarily use the Guild Roster APIs:
- `C_GuildInfo.GuildRoster()` to request updates
- `GetNumGuildMembers()` / `GetGuildRosterInfo()` (or equivalent) to read roster data
- Listen to events like `GUILD_ROSTER_UPDATE`, `PLAYER_GUILD_UPDATE`, etc.

Location/zone details depend on what Blizzard exposes for online guild members; some fields may be unavailable or throttled.

## Local Setup
1. Clone this repo.
2. Symlink/copy the addon folder into your WoW `_retail_/Interface/AddOns/`.
3. Reload UI (`/reload`) and enable the addon.

## Repo Structure
```text
wow-guild-online-widget/
  GuildOnlineWidget/
    GuildOnlineWidget.toc
    init.lua
    util.lua
    core.lua
    ui_widget.lua
    ui_tooltip.lua
    ui_menu.lua
  README.md
  .gitignore
```

## License
MIT (see `LICENSE`).
