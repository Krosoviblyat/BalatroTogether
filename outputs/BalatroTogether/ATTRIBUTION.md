# Attribution and dependency lock

Original mod Lua, procedural UI drawing and together-mark.svg: Balatro Together contributors, MIT, 2026. Built with AI assistance (Codex). The icon is a source SVG; the in-game interface uses original LÖVE drawing routines, not redistributed game art.

Bundled dependency: [rxi/json.lua](https://github.com/rxi/json.lua), MIT, copyright (c) 2020 rxi. Version 0.1.2, commit `dbf4b2dd2eb7c23be2773c89eb059dadd6436f94`. SHA256 of vendor/json.lua: `0eaccda57fabc0330736de25f45cf589821a42b5e0fe02e4e3125f7dc0bf2b7e`. Complete upstream license is preserved at the top of vendor/json.lua. `core/save_json.lua` is an MIT-attributed adaptation of that same version with a linear escaped-string decoder for large checkpoint archives; the original vendor file remains byte-identical.

External required loaders (not bundled):

- [Lovely v0.10.0](https://github.com/ethangreen-dev/lovely-injector/releases/tag/v0.10.0), GPLv3. Windows release ZIP SHA256 `7f481f984ab8ee633c90ce18220c88a2da8f93ca86b6c3e3ff70a725c05807ab`. Use winmm.dll from the official ZIP.
- [Steamodded 26.1002.0](https://github.com/Steamodded/smods/releases/tag/26.1002.0), GPLv3, commit `af0fdb1eb2c9e191262c128bc88bbc4da991e12d`. Its license is supplied with its own download.
- LÖVE 11.5, LuaJIT and LuaSocket: provided by the user's installed Balatro runtime, not redistributed. See the game's own license notices.

Development tests use lupa 2.8 (MIT) privately; players do not need Python or lupa.

Research references: [Co-op Anything](https://github.com/cranebeaker/coop-anything), [Balatro Multiplayer](https://github.com/Balatro-Multiplayer/BalatroMultiplayer), [MultiplayerAPI](https://github.com/Balatro-Multiplayer/BalatroMultiplayerAPI). Their source/assets are not bundled or incorporated. Their documentation informed the evaluation of transport and integration options.

Cryptid 0.5.17c (SpectralPack and contributors), GPLv3, and Amulet 3.6.1 (frostice482 and contributors), GPLv3, are separate bundled components in the full installer. Their exact source archives, notices and licenses are included. No upstream game art was copied into Together. New compatibility code/UI are AI-assisted original work.
