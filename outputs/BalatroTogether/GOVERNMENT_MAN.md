# Government Man — 0.8.6-dev

Native Legendary Joker, base cost $20, starting X2 Mult. Every newly acquired
Negative Joker adds X0.5 to this multiplier. On every second acquisition, a
random owned non-Negative Joker becomes Negative using the native edition/slot
logic. Government Man can be selected. If all Jokers are already Negative,
the multiplier still grows and the conversion has no target.

Acquisitions are local to the owner and occur while Government Man is owned
and active. Shop/pack/generated Jokers and received donations use Steamodded's
native card-added event. Changing an already-owned card's edition does not
count as a pickup. Blueprint copies scoring; it does not duplicate growth.
Existing Negatives are not retroactively counted. Saved and donated copies
retain their exact multiplier and two-pickup progress.

The supplied artwork is registered as a native atlas. Government Man appears
in the Legendary collection and normal Legendary generation (including The
Soul's generation route); he is not added to the ordinary Common shop pool.
Native popups, juice animations and Negative edition effects are used.

All party members must update to gameplay 0.8.6-dev. Native 2-client verification
passed 13 cases including Legendary generation, X2/X2.5/X3/X4 progression,
real slot bonuses, donation replay/rejection, save/restore and actual hand
scoring. Unit regressions also cover Blueprint, retriggers and failed pickups.

Installer and launcher now say: come on in and join the coop fest!
The 0.8.5 game-DLL preflight, public signed updater, backups and running-game
protection remain in place. No live game or save was modified during testing.
