# Balatro modding plan

- Store/app: Steam / 2379780. Installed game 1.0.1o-FULL, Windows x64, LÖVE/LuaJIT.
- Executable SHA256: 0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47.
- Route: Steamodded 26.1002.0 plus Lovely 0.10.0. No executable editing.
- Lab: workspace copies; separate Lovely mod directory and LÖVE save identity per process. Original game and saves read only, fingerprint before/after.
- Networking: in-game TCP host thread plus three clients. No paid service or external accounts.
- Unknowns: exact available Steam bindings; all native hook interactions; long-run/boss behavior. Resolve with executable clients rather than headless claims.
