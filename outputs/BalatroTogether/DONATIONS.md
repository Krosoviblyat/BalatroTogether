# Donation Box

Open **F8 → Donation Box**, or the Donation Box button on the in-run HUD. Trade while unready, in your shop or between blinds, after native animations finish. If you already readied up, use **Unready to Trade**. Trading never interrupts a hand that is resolving.

Your inventory appears on the left and the team's eight-slot box on the right. Choose **Send To: Everyone** or a specific teammate, then **Donate** an owned card. Teammates use **Take** when they have room. The donor may **Take Back** an available gift, including an addressed gift. Pages show four cards at a time.

Supported cards are vanilla and Cryptid Jokers, Tarot, Planet, Spectral and Code consumables. Built-up ability values, editions, Perishable/Rental flags and pinned state travel with the card. Passive effects are removed from the donor and applied to the recipient. Negative cards bring their normal extra inventory slot. Eternal or currently debuffed cards, playing cards, vouchers, shop stock and other mods' custom cards cannot be donated. A large or incompatible native state is refused safely.

Bots automatically unready, accept a gift addressed to their seat, then ready again. They leave Everyone gifts for humans. They can use supported donated consumables through their existing strategy; receiving a targeted Tarot or Spectral does not add new targeting intelligence.

The donor gives up the original before the host makes the gift available. A refused deposit restores the original. The host reserves each gift for one recipient, so simultaneous Take requests cannot create two copies. Construction and native effects run once, followed by an acknowledged commit. A failed reconstruction releases the reservation. Inventory actions and readying are held while a local transfer is pending.

A temporary connection loss retains the reservation for the same open game and seat. Keep that game open until delivery finishes. Closing a game cannot recover its native inventory; there is no disk-backed transfer recovery or host migration. If the host retires an absent seat, its uncollected reservations become available, and gifts addressed to it become public. Fast Restart clears the box and every old-run transfer along with the run's ordinary inventories.

The screen uses damped spring entrances, card lift/tilt, pressed-button squish, a gift-box pulse, curved card flights and small celebration particles. Settings → Reduced Motion or intensity zero disables these movements. Card art comes from the user's installed game at runtime; no game art is distributed in the ZIP.

This is a private-friends development build. Like score reports, donated native card state comes from the owning client; this is not an anti-cheat authority. See TEST_RESULTS.md for native transfer, reconnect, capacity and bot evidence and KNOWN_ISSUES.md for broader compatibility limits.

Cryptid 0.5.17c compatibility: finite Amulet ability values and supported cry_ editions transfer. Storage/double-sided cards and temporary ://Multiply effects cannot transfer. See CRYPTID.md for bounds and progression restrictions.
