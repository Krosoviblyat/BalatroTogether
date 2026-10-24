# Research and dependency pins

Research performed 2026-10-21 against the owned Windows Steam game. Native source was inspected privately for scoring/event order and round transitions; no proprietary source is distributed.

- [coop-anything](https://github.com/cranebeaker/coop-anything): read instructions, playbooks and MCP configuration; research guidance, not game transport.
- [Balatro Multiplayer](https://github.com/Balatro-Multiplayer/BalatroMultiplayer): GPLv3, evaluated two-seat assumptions; no source copied.
- [Multiplayer API](https://github.com/Balatro-Multiplayer/BalatroMultiplayerAPI): GPLv3, authenticated MQTT/API service; no source copied. Original standalone TCP selected for reproducible tests without external credentials.
- [Lovely v0.10.0](https://github.com/ethangreen-dev/lovely-injector/releases/tag/v0.10.0): pinned Windows x64 injector using winmm.dll. Archive SHA256: `7f481f984ab8ee633c90ce18220c88a2da8f93ca86b6c3e3ff70a725c05807ab`.
- [Steamodded 26.1002.0](https://github.com/Steamodded/smods/releases/tag/26.1002.0): commit `af0fdb1eb2c9e191262c128bc88bbc4da991e12d`; root includes lovely/ and src/ directories.
- [Steam matchmaking API](https://partner.steamgames.com/doc/api/ISteamMatchmaking) and [LuaSteam friends API](https://luasteam.readthedocs.io/en/v3.0.0docs/friends.html): capability references. Local runtime has overlay/persona helpers but no Lua invitation/lobby binding. The 0.3.2 bridge calls the game's existing native exports. See STEAM.md for API sources and verification limits.

The MIT JSON decoder is the sole vendored runtime dependency; exact attribution/digest is in ATTRIBUTION.md. Loaders install separately. Co-op addon listings without verified reusable licensed source were not treated as proof of a working four-player implementation.
