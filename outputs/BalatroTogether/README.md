# THUNDRCK - curated fun seed (0.8.7-dev)

Enter **THUNDRCK** (eight letters) in Together Settings > Seed, or the native
seed field. Start a fresh run. All players need gameplay 0.8.7-dev or later.
This is an intentionally scripted seed mode in Together, not a natural RNG
discovery. The same text in vanilla or 0.8.6 does not provide these guarantees.

Recommended first test: Red Deck, White Stake, Cryptid Mainline. The actual
card pool and remaining random rolls still depend on deck/gameset/actions.

1. Beat Small Blind. The first shop has a **$1 Negative Abstract Joker**.
   Buy it for an affordable start. Its purchase predates Government Man and
   therefore does not retroactively upgrade him.
2. Beat Big Blind too: the second played blind, without skipping Small.
   Its shop stocks a normal **Buffoon Pack**. Buy and open it; taking a card
   or skipping its choices both complete the paid pack normally.
3. **Reroll that same shop after closing the pack.** The first qualifying
   reroll stocks one real **The Soul** in the shop at its native price.
   Buy it, keep a Joker slot free, and use it: it summons **Government Man**.
4. Subsequent shop openings start with a **Negative Blueprint**, at its
   normal price. Buy Negative Jokers after getting Government Man to grow him.

At the opening shuffle of each blind, the seed moves an existing high straight
flush to the draw end of the deck. With a standard complete deck and at least
five hand slots, this gives an opening Royal Flush. If the modified deck has
no straight flush, it uses an available flush. It does not create or change
playing cards, enlarge the hand, remove debuffs, disable bosses or guarantee
victory. A modified deck/hand size/boss can interfere. Other draws, remaining
shop slots, pack choices and rerolls keep their native RNG.

The guaranteed Soul is **once per player per run**. It requires the purchased
Buffoon in the second won-blind shop; free tag packs do not qualify. Rerolling
past the offered Soul does not create a replacement. Other Souls keep normal
Legendary RNG. Manual party saves preserve the offer/use flags and build.
Fast Restart starts a fresh copy of the seed. Ordinary seeds and random runs
do not activate any of these rules. This is a seeded run and follows native
seeded-run achievement restrictions.

The already open Government Man demo remains a separate 0.8.6 test. This update
does not change a currently running match. Close Balatro before installing.

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

# Balatro Together 0.8.2-dev

Saved Runs is the hub for every manual party checkpoint. Saving again updates
that run's entry; a different party or Fast Restart keeps a separate entry,
even when using the same seed. Select any entry to reopen its joinable lobby.

0.8.2 fixes free tag packs getting stranded between blinds. Open and choose
Spectral, Arcana, Celestial, Standard and Buffoon rewards normally. The party
waits for all pack choices before progressing.

0.8.1 fixes The Chromatic's negative hand scores and Amulet ante proposals.
Signed score debt is preserved, then positive hands repay it. Credits now sits
beside Together Options and in the lobby. Credits > Open Crash Reports opens
the local TogetherReports folder in the active save profile. Reports are never
uploaded automatically; share last-crash.txt when reporting an uncaught crash.

Four-player Cryptid co-op with Steam tables, native bots, donations, team/personal
bets, reward dice, a boss wheel and endless play.

This main release adds The Harbinger as a native Boss Blind with the supplied
purple chip. It plays five-card hands from its own deck; its score damages net
team chips after each team hand. CLASH uses native bouncing text and sound.
The first boss is protected. Mixed mode rolls a 20% encounter chance on later
regular bosses from Ante 2; finale bosses stay native. Boss Rules / Stakes offers
four difficulty tiers and an explicit Quick Duel test mode.

Checkpoints are **manual**. The host chooses F8 > Save Checkpoint or Save & Leave
between blinds. Continue Saved Party opens a new joinable lobby/code; the original
players recover their builds. The host presses Continue Saved Run when all builds
are restored. No automatic checkpoint interrupts a new run or blind transition.

Use the full 0.8.2 setup with Balatro closed. The normal desktop launcher can
receive this signed update from 0.7 once published. Private-repository access is
still required for online updates. Every player must use the same gameplay build.
Native saves remain in the ordinary Balatro profile; the Harbinger Lab is separate.

Pinned Windows Steam Balatro 1.0.1o / Lovely 0.10.0 / Steamodded 26.1002.0 /
Cryptid 0.5.17c / Amulet 3.6.1. User-owned game files are never redistributed.
Original code MIT; upstream components retain their licenses. AI-assisted work.

See SAVES.md, CRYPTID.md, BOTS.md, and the included installer guide for details.
