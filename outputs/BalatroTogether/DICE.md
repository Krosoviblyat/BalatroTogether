# Reward Dice

Every **two won team blinds**, each non-retired player earns **one gold d6 and one red d20**. These are free personal rewards, separate from Bet Pot. There is no stake, red-loss wager or shared-pot withdrawal.

Open **F8 -> Reward Dice** or click **Dice** on the HUD. Stay unready in your shop or between blinds. Click **Roll Gold D6** or **Roll Red D20**; the die tumbles in a tray and its upward resting face decides the reward.

- **Gold d6:** adds **$5 per pip** to your own native wallet: $5-$30.
- **Red d20:** adds its face as **+1 to +20 Mult to every hand in your next shared blind**. It is additive Mult, before native blind modifiers and card/joker scoring. It expires when the following shared blind begins. Multiple saved red dice rolled before the same blind add together.

Saved dice remain yours until used, leaving the table or restarting the party. You can watch another player's most recent die using their seat button. Everyone's outcome is host-authoritative; spectators do not receive or spend the roller's reward. Gold rewards can also be redeemed at team victory; red rewards require an upcoming active blind. Bots bank their dice rather than rolling them automatically.

The cube and regular icosahedron are original procedural models. Their fixed-step rigid body simulation uses gravity, spin, contact impulses, friction and tray walls. The host starts each throw and chooses the result from the actual resting upward face, then clients replay that throw. If a throw cannot settle on a face within ten simulated seconds, the host retries up to eight times; if all fail, the owned die is kept. This is a small game physics simulation, not a certified physical dice model.

Rolling holds that player's ready/shop/spending controls until completion. Gold uses cumulative native payout receipts to prevent duplicate rewards on retry or reconnect. Keep the original client process open to reconnect. A completed red result activates once at the next blind start and never rewrites your permanent poker-hand levels or occupies a joker slot. Party restart clears tickets, pending outcomes, credits and Mult bonuses.

Visuals include shaded 3D faces, perspective-compressed pips/numbers, soft shadows, motion trails, collision shake, button springs, coin/shard bursts and a large reward reveal. Reduced Motion or intensity 0 uses the same host result without movement. Celebration Effects removes trails and bursts; Notification Sounds controls the added impact/reveal sounds. All code/art is original; no Dice A Million assets were copied.

## Boss Reward Wheel

Every won Boss Blind earns each non-retired player **one personal wheel spin**, independently of the every-two-wins dice. Open Reward Dice and choose **SPIN BOSS WHEEL** while unready in a shop or between blinds. Saved spins remain available within this run. Each player gets their own reward, with no stake or loss outcome. Teammates can watch the spin using the seat buttons. Bots currently save spins.

The original wheel has 100 outcome slots grouped into 21 prize sectors. The pointer selects the sector at the end of the host's deterministic spin. Most packages occupy five slots; Crown Jewel occupies four and Perfect Hundred occupies one. The same host spin replays for every client, with a flicking pointer, tick sounds, illuminated rim, eased slowdown and a spring celebration. **WHEEL PRIZES** shows the complete table before spending a spin. Reduced Motion resolves the same reward without movement.

| Slots | Prize | Reward |
|---|---|---|
| 1–5 | Treasury | $35 |
| 6–10 | On the House | 3 free shop refreshes |
| 11–15 | Second Wind | +2 hands next blind |
| 16–20 | Fresh Start | +3 discards next blind |
| 21–25 | Chip Cache | +100 chips per hand next blind |
| 26–30 | Power Surge | +25 Mult per hand next blind |
| 31–35 | Stars Align | All poker hands +1 level |
| 36–40 | Merchant Gift | $50 and 2 free refreshes |
| 41–45 | Full Toolkit | +1 hand, +1 discard, +100 chips next blind |
| 46–50 | Lucky Orbit | All poker hands +1 level and $25 |
| 51–55 | Hot Streak | +2 hands and +25 Mult next blind |
| 56–60 | Deep Pockets | +3 discards and +200 chips next blind |
| 61–65 | Shopping Spree | 6 free refreshes |
| 66–70 | Constellation | All poker hands +2 levels |
| 71–75 | Golden Orbit | $75 and all poker hands +1 level |
| 76–80 | Limit Break | +2 hands, +2 discards, +35 Mult next blind |
| 81–85 | Overdrive | +250 chips and +40 Mult next blind |
| 86–90 | Cosmic Market | All poker hands +2 levels and 4 free refreshes |
| 91–95 | Royal Fortune | $100, all poker hands +2 levels, +50 Mult next blind |
| 96–99 | Crown Jewel | $50, +3 hands, +3 discards, +300 chips, +60 Mult next blind |
| 100 | Perfect Hundred | $100, all poker hands +3 levels, 6 free refreshes, +3 hands, +3 discards, +400 chips, +100 Mult next blind |

Cash goes to the spinner's own wallet. Hand-level upgrades last for the rest of the current run. Free refreshes are banked for this run and are consumed after any native free rerolls, without increasing the next paid reroll's price. Extra hands/discards, chips and Mult activate only for the next shared blind, then expire. Chips and Mult are added before the native blind's modifiers. Saved red dice and wheel bonuses stack.

Spin completion and native reward delivery hold that player's ready, shop-exit and spending controls until acknowledged. Per-hand delivery checkpoints prevent a transient native level-up failure from duplicating already delivered levels. Party restart clears all wheel tickets, effects and credits. Keep the same client process open for reconnect. All party members must use the same mod version. Cross-account Steam wheel delivery and broad third-party mod combinations remain unverified; The pinned Cryptid/Amulet bundle is supported; arbitrary extra mods remain unverified.

## Fuck the Table jackpot challenge

Choose **FUCK THE TABLE** while you own a boss spin and are unready in the shop or between blinds. It spends **one earned spin**, the same as an ordinary wheel spin. Press and release **Space 32 times in eight seconds** to guarantee slot 100, Perfect Hundred. Holding Space and keyboard repeat do not count. The host owns the timer and validates progress. The wheel still spins and lands on the jackpot sector after a win.

Missing the challenge does not waste the spin: it resolves the normal wheel result. Its normal result can also naturally be a jackpot. The reward belongs only to the spinner. Progression remains held through the challenge, spin and native delivery. The title, timer, progress fill, hit feedback and celebration obey the existing effects and motion settings; reducing motion does not alter the challenge requirement.

Default endless keeps earned dice, spins and unused bonuses after the ante-eight boss. Tickets and effects still clear on party restart.
