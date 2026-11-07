# FontBridge

**Register user-provided fonts with LibSharedMedia and manage fonts for Blizzard UI areas in WoW Forever.**

FontBridge is a standalone addon for World of Warcraft Forever. It adds your own font files to [LibSharedMedia-3.0](https://www.curseforge.com/wow/addons/libsharedmedia-3-0), so any addon that uses LibSharedMedia can offer them in its font selector. It also provides per-area font and style settings for supported Blizzard UI elements.

FontBridge does not require FontManager and does not modify FontManager, Shadowed Unit Frames, or other addons. Third-party addons keep their own font controls; select a registered font in each addon's settings.

## Features

- Register `.ttf` and `.otf` files with a display name.
- Share registered fonts with LibSharedMedia-compatible addons.
- Preview, refresh, and remove registered entries from the `/fb` window.
- Choose fonts for supported Blizzard UI areas, with scale, outline, and shadow options where the client supports them.
- Save font entries and area settings between sessions.
- Korean and English UI, with additional translations for the main interface.

## Install

1. Extract the `FontBridge` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. Enable FontBridge from the AddOns list at character selection.
3. Log in and type `/fb` to open its window.

The included release archive contains **no font files**. You must supply fonts that you are licensed to use.

## Add your own fonts

1. Copy `.ttf` or `.otf` files into `Interface/AddOns/FontBridge/Fonts/`, or keep them in another addon and use that addon's full `Interface\\AddOns\\...` path.
2. Fully exit and restart the game after copying a new font file. WoW discovers addon files at startup.
3. Open `/fb`, enter a display name and the font filename (or full Interface path), then choose **Add**.

Removing an entry from FontBridge does not delete its font file. LibSharedMedia has no unregister operation, so use `/reload` after removing an entry to clear it from other addons' lists for the current session.

## Choose fonts

Open `/fb` or `/fontbridge` and use **Area Settings** to choose fonts for supported Blizzard UI areas. Each area's help text describes what it controls. FontManager's area-wide font replacement is paused while FontManager is loaded to avoid two addons changing the same Blizzard UI fonts; LibSharedMedia font sharing remains available.

For SUF, Bartender, and other third-party addons, open that addon's own settings and select the font registered by FontBridge. FontBridge does not replace third-party addon-specific font settings.

## Troubleshooting

- **A font does not load:** Check its filename, extension, path, and game restart. The font must be readable by the WoW client.
- **The font appears in FontBridge but not another addon:** Confirm that the addon uses LibSharedMedia-3.0 and reload the UI after registration.
- **Some characters are missing:** The font file must contain the glyphs for those characters. FontBridge cannot add missing glyphs.
- **A new file is not listed:** Fully exit and restart WoW; `/reload` alone does not make a newly copied addon file available.

## Compatibility

This release targets WoW Forever interface `16001` (client build `1.60.1`, build `70862`). It bundles LibStub, CallbackHandler-1.0, and LibSharedMedia-3.0 so it can register fonts even when another addon does not load those libraries first.

## Credits and license

FontBridge author: **Arthen Mithrill <LIGHTNING SPEED> KR PvP Horde**.

The bundled LibSharedMedia-3.0 library is licensed under LGPL-2.1; its license is included in `Libs/LICENSE-LGPL-2.1.txt`. FontBridge's own source license has not yet been selected.
