# Repository and CurseForge listing

## Repository description

Register user-provided fonts with LibSharedMedia and manage font settings for Blizzard UI areas in WoW Forever.

Suggested topics: `wow`, `world-of-warcraft`, `wow-addon`, `wow-forever`, `libsharedmedia`, `fonts`, `lua`.

## CurseForge summary

Share your own fonts with LibSharedMedia-compatible addons and manage fonts for supported Blizzard UI areas. Includes no font files.

## CurseForge project description

FontBridge makes user-provided fonts available to addons that use LibSharedMedia-3.0. Register `.ttf` or `.otf` files with a display name, then select them from compatible addon font menus, including SUF and Bartender.

FontBridge also provides a compact `/fb` window for font preview and list management, plus per-area font settings for supported Blizzard UI elements. Font size, outline, and shadow controls are shown where the client supports them.

FontManager is not required. FontBridge does not edit FontManager or other addons. Third-party addons keep their own font settings. The archive contains no fonts; users must supply font files they are licensed to use.

### Project metadata

- **Game/version:** World of Warcraft Forever; interface `16001` (client build `1.60.1`, build `70862`).
- **Author display:** Arthen Menethil <LIGHTNING SPEED> KR PvP Horde.
- **License:** MIT for FontBridge-authored source. Bundled libraries retain their own terms; see `THIRD_PARTY_NOTICES.md`.
- **Project icon:** `assets/FontBridge-icon.png` (1254×1254 PNG; meets the 400×400 minimum).
- **Release archive:** Build with `python3 tools/package_release.py`; the archive contains the addon files and no font binaries.

## Screenshots

The following captures are ready to upload to the CurseForge project's Images gallery:

- `assets/main.png` — the Fonts tab with an empty list.
- `assets/preview.png` — the Fonts tab showing the font preview and two registered sample fonts.
- `assets/setting.png` — the Area Settings tab.

The captures show only the FontBridge window; they do not include the character, chat, or game world. Font binaries are not included in the project archive.
