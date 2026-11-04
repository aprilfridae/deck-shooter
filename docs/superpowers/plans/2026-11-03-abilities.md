# Abilities Implementation Plan (Phase 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all 5 ability cards work in the test room, with perks on every tier, cooldown bars on the HUD and the Card core data changes.

**Architecture:** Card numbers and every ability rule are pure and run under Lune: `Cards`, a new `Ability` module in `src/shared/CardCore/`, `Combat` and `Weapon`. `AbilityServer.server.luau` owns cooldowns and effects and publishes them as attributes. The client sends only "use slot N", then shows the results.

**Tech Stack:** Luau, Rojo 7.7.1 with live sync, Lune 0.11.1.

**Spec:** `docs/superpowers/specs/2026-11-03-movement-combat-design.md` (Ability cards, Decisions added before Phase 3, Architecture)

## Global Constraints

- The server alone controls ability use. Remote payloads go through a parser, as in `Requests.luau`.
- Cards read deck and stats from Card core. Cards reset at the start of each round; until Phase 4, that means each spawn.
- A cooldown starts when the ability is used.
- Perk strength is 80% at Field, 90% at Black-Site and 100% at Prototype.
- Input is read only through `src/client/Input.luau`.
- Shared modules stay flat with sibling `require("./Name")`, so modules that need `Cards` live in `src/shared/CardCore/`.
- River does all playtesting. Scripts are never edited through Studio MCP.

## Plan decisions (the spec leaves these open)

| Decision | Value | Why |
| --- | --- | --- |
| Flat cooldowns | A top-level `cooldown` field on the card, read through `Cards.cooldown` | The stat ceiling test requires every `stats` entry to scale by tier. |
| Dash timing | The client asks, the server approves, then the client dashes | Adds one ping of delay, but the movement guard is always warned first. If it feels late, this is the first thing to revisit. |
| Dash movement | Slides the character 0.12s along a straight path that stops at walls, like a climb | Gives an exact distance. You land in the air at sprint speed. |
| Dash in the guard | The guard stops checking briefly after a dash or push | It already has this grace for spawning. |
| Shield | All gun and mine damage hits it, including headshots | The spec says other damage beyond the shield's HP is lost. |
| Ally check | Same Roblox `Team`; with no teams, everyone else is an enemy | Phase 4 only has to assign teams. |
| Second mine | Placing one removes your old one | Keeps the one-active rule without refusing the key press. |
| Mine effect | Damages and slows every enemy within 6 studs, then disappears | The cards list one damage value and no blast size. |
| Mine with no floor | Nothing is placed and the cooldown is not spent | A miss should not cost 30 seconds. |
| Owner dies | Their mine is removed and their effects end | Cards reset each spawn. |
| Mine hiding | The server keeps the mine visible; each client fades it locally | Roblox has no per-player visibility. A cheat could reveal it. |
| Slow | Applied by the client from server attributes | Movement is client-owned. A cheat could ignore it. |
| Test keys | T next test deck, Y next tier; two decks cover all 5 cards; Studio only, never saved | River can compare every card and tier. Phase 4 removes them. |
| Overclock refill | Adds to the active gun, rounded down, capped at a full magazine | "80% of a magazine" stays meaningful when the magazine is not empty. |

**Starting values to tune by feel** (`Config.luau`): `DashSeconds = 0.12`, `DashCamoSeconds = 1.5`, `CamoTransparency = 0.9`, `MoveGraceSeconds = 0.5`, `PushRadius = 15`, `PushSpeed = 70`, `PushRise = 35`, `MineTriggerStuds = 6`, `MineArmSeconds = 1`, `CooldownSegments = 10`.

**Out of scope:** ability art and sound, a deck-building screen, round flow, assigning teams.

## Review Focus

1. A use request with `"1"`, `0`, `4`, `1.5`, NaN or a table: refused, never an error. Test in Task 2.
2. A second use before the cooldown ends, or in the same instant: refused and the cooldown is unchanged. Test in Task 2.
3. A save that has not loaded, so there is no deck: no abilities and no error. Test in Task 2.
4. An instant-kill headshot on a shield with 1 HP or full HP: the shield breaks and the player lives. Test in Task 3.
5. A player who dies with an effect running: the delayed end must not touch the next life. A new loadout has no fire-rate bonus (test in Task 3). Each effect checks that its `slots` table is still current (Task 4).

---

### Task 1: Card data

**Files:**
- Modify: `src/shared/CardCore/Cards.luau`, `src/shared/CardCore/Config.luau`
- Test: `tests/cards_spec.luau`

**Interfaces:**
- Produces: `Cards.cooldown(id: string, tier: string): number`; `Cards.perkScale(tier: string): number`; the `Config` values above plus `PerkPower = { Field = 0.8, BlackSite = 0.9, Prototype = 1 }`.

- [ ] **Step 1: Write the failing tests**

```lua
it("applies the Prototype data changes", function()
	expect(Cards.stat("aegis_shell", "Prototype", "duration")).toBe(3.75)
	expect(Cards.stat("arc_mine", "Prototype", "slowSeconds")).toBe(1.875)
	expect(Cards.byId.arc_mine.perk).toBe("hidden_until_triggered")
end)

it("has no ceiling exemptions left", function()
	for _, id in Cards.ids do
		expect(Cards.byId[id].ceilingExempt).toBeNil()
	end
end)

it("gives each card its spec cooldown", function()
	expect(Cards.cooldown("phase_dash", "Field")).toBe(12)
	expect(Cards.cooldown("phase_dash", "Prototype")).toBe(10)
	expect(Cards.cooldown("overclock", "BlackSite")).toBe(25)
	expect(Cards.cooldown("recon_pulse", "Field")).toBe(20)
	expect(Cards.cooldown("aegis_shell", "Prototype")).toBe(25)
	expect(Cards.cooldown("arc_mine", "Field")).toBe(30)
end)

it("scales perks by tier", function()
	expect(Cards.perkScale("Field")).toBe(0.8)
	expect(Cards.perkScale("BlackSite")).toBe(0.9)
	expect(Cards.perkScale("Prototype")).toBe(1)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 4 failed.

- [ ] **Step 3: Implement**

Add `cooldown = 25 / 20 / 25 / 30` to Overclock, Recon Pulse, Aegis Shell and Arc Mine. `Cards.cooldown` returns `card.cooldown` or else the tier's `stats.cooldown`. Change the three spec values, remove both `ceilingExempt` lines, and simplify the ceiling test. Add the Config values.

- [ ] **Step 4: Run to verify they pass**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed.

- [ ] **Step 5: Commit**: "Apply ability card data changes".

### Task 2: Ability rules

**Files:**
- Create: `src/shared/CardCore/Ability.luau`
- Test: `tests/ability_spec.luau` (add to `listed` and the `require` lines in `tests/run.luau`)

**Interfaces:**
- Consumes: `Cards.cooldown`, `Cards.perkScale`, `Cards.stat`, `Config` from Task 1.
- Produces:
  - `type Slot = { cardId: string, tier: string, readyAt: number }`
  - `Ability.new(deck: { any }?): { Slot }`, `Ability.parseSlot(raw: any): number?`
  - `Ability.ready(slots, index: number, now: number): Slot?`, `Ability.spend(slot: Slot, now: number)`
  - `Ability.camoSeconds(tier): number`, `Ability.refillShots(mag: number, tier): number`, `Ability.teamRevealSeconds(tier): number`, `Ability.pushSpeed(tier): number`, `Ability.mineVisibility(tier): number`
  - `Ability.mineTriggered(placedAt: number, now: number, distance: number): boolean`
  - `Ability.slowFactor(pct: number, untilTime: number, now: number): number`

- [ ] **Step 1: Write the failing tests**

```lua
local deck = { { cardId = "phase_dash", tier = "Field" }, { cardId = "arc_mine", tier = "Prototype" } }

it("accepts only whole slot numbers from 1 to 3", function()
	expect(Ability.parseSlot(1)).toBe(1)
	expect(Ability.parseSlot(3)).toBe(3)
	for _, bad in { 0, 4, 1.5, "1", 0 / 0, math.huge, {} } do
		expect(Ability.parseSlot(bad)).toBeNil()
	end
	expect(Ability.parseSlot(nil)).toBeNil()
end)

it("has no abilities before the deck loads", function()
	expect(#Ability.new(nil)).toBe(0)
	expect(Ability.ready(Ability.new(nil), 1, 0)).toBeNil()
end)

it("is ready at the start, then waits out the cooldown from the moment of use", function()
	local slots = Ability.new(deck)
	local slot = Ability.ready(slots, 1, 5)
	Ability.spend(slot, 5)
	expect(slot.readyAt).toBe(17)
	expect(Ability.ready(slots, 1, 5)).toBeNil()
	expect(Ability.ready(slots, 1, 16.9)).toBeNil()
	expect(Ability.ready(slots, 1, 17)).toBe(slot)
end)

it("does not spend a cooldown just by checking it", function()
	local slots = Ability.new(deck)
	Ability.ready(slots, 2, 5)
	expect(slots[2].readyAt).toBe(-math.huge)
end)

it("does not share the deck table it was given", function()
	local slots = Ability.new(deck)
	Ability.spend(slots[1], 1)
	expect(deck[1].readyAt).toBeNil()
end)

it("scales each perk by tier", function()
	expect(Ability.camoSeconds("Field")).toBeCloseTo(1.2)
	expect(Ability.camoSeconds("BlackSite")).toBeCloseTo(1.35)
	expect(Ability.camoSeconds("Prototype")).toBeCloseTo(1.5)
	expect(Ability.teamRevealSeconds("Field")).toBeCloseTo(1.6)
	expect(Ability.teamRevealSeconds("Prototype")).toBeCloseTo(2.5)
	expect(Ability.pushSpeed("Field")).toBeCloseTo(56)
	expect(Ability.mineVisibility("Field")).toBeCloseTo(0.2)
	expect(Ability.mineVisibility("BlackSite")).toBeCloseTo(0.1)
	expect(Ability.mineVisibility("Prototype")).toBeCloseTo(0)
end)

it("refills a share of a magazine, rounded down", function()
	expect(Ability.refillShots(30, "Field")).toBe(24)
	expect(Ability.refillShots(6, "Field")).toBe(4)
	expect(Ability.refillShots(30, "Prototype")).toBe(30)
end)

it("arms a mine after 1 second and triggers it within 6 studs", function()
	expect(Ability.mineTriggered(10, 10.9, 1)).toBe(false)
	expect(Ability.mineTriggered(10, 11, 6)).toBe(true)
	expect(Ability.mineTriggered(10, 11, 6.1)).toBe(false)
end)

it("slows only until the slow ends", function()
	expect(Ability.slowFactor(0.25, 10, 9)).toBeCloseTo(0.75)
	expect(Ability.slowFactor(0.25, 10, 10)).toBe(1)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: the run stops on the missing `Ability` module.

- [ ] **Step 3: Implement** the signatures above. `new` copies `cardId` and `tier` and sets `readyAt = -math.huge`. `teamRevealSeconds` uses the `recon_pulse` `revealTime` for that tier. `parseSlot` requires a number, `raw == raw`, `math.floor(raw) == raw` and a range of 1 to `Deck.SIZE`.

- [ ] **Step 4: Run to verify they pass**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed.

- [ ] **Step 5: Commit**: "Add ability rules".

### Task 3: Gun and damage hooks

**Files:**
- Modify: `src/shared/Guns/Combat.luau`, `src/shared/Guns/Weapon.luau`, `src/server/GunTargets.luau`, `src/server/GunServer.server.luau`, `src/client/Guns.client.luau`
- Create: `src/server/Loadouts.luau`
- Test: `tests/damage_spec.luau`, `tests/weapon_spec.luau`

**Interfaces:**
- Produces:
  - `Combat.absorb(shield: number, amount: number): (number, boolean)` returns shield left and whether it broke
  - `Loadout.fireRateBonus: number`, default 0
  - `Weapon.refill(loadout, shots: number)`
  - `Loadouts`: a module returning the shared `{ [Player]: Weapon.Loadout }` table
  - `Target.shield: { hp: number, onBreak: () -> () }?`, read by `GunTargets.damage`

- [ ] **Step 1: Write the failing tests**

```lua
-- damage_spec
it("takes damage on the shield and loses what is left over", function()
	local left, broke = Combat.absorb(20, 15)
	expect(left).toBe(5)
	expect(broke).toBe(false)
	left, broke = Combat.absorb(20, 50)
	expect(left).toBe(0)
	expect(broke).toBe(true)
end)

it("breaks a full shield on an instant-kill headshot", function()
	local left, broke = Combat.absorb(64, Damage.KILL)
	expect(left).toBe(0)
	expect(broke).toBe(true)
end)

-- weapon_spec
it("fires faster with a fire-rate bonus", function()
	local loadout = Weapon.newLoadout("Assault", "M4") -- 0.1s between shots
	loadout.fireRateBonus = 0.18
	expect(Weapon.tryFire(loadout, 1)).toBe(true)
	expect(Weapon.tryFire(loadout, 1.08)).toBe(false)
	expect(Weapon.tryFire(loadout, 1.09)).toBe(true)
end)

it("starts each life with no fire-rate bonus", function()
	expect(Weapon.newLoadout("Assault", "M4").fireRateBonus).toBe(0)
end)

it("refills the active gun without passing a full magazine", function()
	local loadout = Weapon.newLoadout("Assault", "M4")
	loadout.slots.primary.ammo = 3
	Weapon.refill(loadout, 24)
	expect(Weapon.ammo(loadout)).toBe(27)
	Weapon.refill(loadout, 24)
	expect(Weapon.ammo(loadout)).toBe(30)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 5 failed.

- [ ] **Step 3: Implement**

`Weapon.tryFire` divides the interval by `1 + loadout.fireRateBonus`. In `GunTargets.damage`, when `target.shield` exists, run `Combat.absorb`, store the new HP in `target.shield.hp` and the character attribute `ShieldHp`, call `onBreak` if it broke, clear the shield, and return false without touching health. Move `GunServer`'s `loadouts` table into `Loadouts.luau`. In `Guns.client`, `canFire` divides its interval by `1 + (player:GetAttribute("FireRateBonus") or 0)`.

- [ ] **Step 4: Run to verify they pass**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed.

- [ ] **Step 5: Commit**: "Add shield and Overclock hooks to guns".

### Task 4: Ability server, keys, HUD, Overclock and Recon Pulse

**Files:**
- Create: `src/server/AbilityServer.server.luau`, `src/client/Abilities.client.luau`
- Modify: `src/client/Input.luau`, `src/client/Hud.client.luau`

**Interfaces:**
- Consumes: `Ability`, `Cards`, `PlayerCards.get`, `PlayerCards.profileLoaded`, `GunTargets`, `Loadouts`, `Weapon.refill`.
- Produces:
  - Remotes in `ReplicatedStorage.AbilityRemotes`: `Use(slot)` and `TestDeck(action: "deck" | "tier")` from the client; `Reveal({ model, seconds }[])` to the client
  - Player attributes for N = 1 to 3: `AbilityNId`, `AbilityNTier`, `AbilityNReadyAt` (`workspace:GetServerTimeNow()` time), `AbilityNCooldown`
  - In `AbilityServer`: `handlers: { [cardId]: (player, target, slot) -> boolean? }`, where returning `false` means nothing happened and the cooldown is not spent; `isEnemy(owner: Player, target: GunTargets.Target): boolean`
  - `Input.readAbility(): { [string]: boolean }` with `slot1`, `slot2`, `slot3`, `testDeck`, `testTier`

- [ ] **Step 1: Build the server core**

Each spawn replaces the player's `slots` with `Ability.new(deck)` and clears their mine, shield and effects. Rebuild on `profileLoaded`, because the save can load after the first spawn. On `Use`: parse the slot, require a living target, call `Ability.ready`, run the handler, then `Ability.spend` and publish attributes. Every delayed effect first checks that `slots[player]` is still the table it started with.

- [ ] **Step 2: Build the test decks**

`TestDeck` is ignored unless `RunService:IsStudio()`. It keeps the session choice in server memory and never writes to the save. `TEST_DECKS` is `{ phase_dash, overclock, recon_pulse }` and `{ aegis_shell, arc_mine, phase_dash }`. Tiers step through `Tier.order`. Each change rebuilds `slots`.

- [ ] **Step 3: Implement the two simplest cards**

Overclock sets `loadout.fireRateBonus` and the `FireRateBonus` player attribute. When `duration` ends, it clears both and calls `Weapon.refill` with `Ability.refillShots`. Recon Pulse finds living enemies within `radius` of the player. It fires `Reveal` to the owner with `revealTime`, and to same-team players with `Ability.teamRevealSeconds`.

- [ ] **Step 4: Build the client**

Add 3, 4, 5, T and Y to `Input.readAbility`, returning all false while a text box has focus. `Abilities.client` fires `Use` on a key press, but not while the `Climbing` attribute is set. On `Reveal`, it adds an `AlwaysOnTop` `Highlight` to each model and removes it after `seconds`. The HUD shows 3 bars, above the health bar, labelled with key and card name. Each bar has `CooldownSegments` segments that fill as `AbilityNReadyAt` approaches.

- [ ] **Step 5: Run tests and commit**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed. Commit: "Add ability server, HUD bars, Overclock and Recon Pulse".

### Task 5: Phase Dash

**Files:**
- Create: `src/server/MoveGrace.luau`
- Modify: `src/server/AbilityServer.server.luau`, `src/server/MovementGuard.server.luau`, `src/client/Movement.client.luau`

**Interfaces:**
- Consumes: `MoveState.startClimb` and `finishClimb`, `Ability.camoSeconds`.
- Produces: `MoveGrace.give(player: Player, seconds: number)` and `MoveGrace.given` (a signal, like `PlayerCards.profileLoaded`); remote `Dash(distance: number)` to the client.

- [ ] **Step 1: Warn the guard**

`MovementGuard` listens to `MoveGrace.given` and sets `guard.settledAt = now + seconds`, so the existing grace resets its track. The grace also adds twice the player's ping.

- [ ] **Step 2: Add the handler**

Call `MoveGrace.give(player, Config.MoveGraceSeconds)`, then fire `Dash` with the `distance` stat. Then set `Config.CamoTransparency` on the character's visible parts for `Ability.camoSeconds(tier)`, saving each part's original transparency and restoring it at the end.

- [ ] **Step 3: Add the client dash**

On `Dash`, take `humanoid.MoveDirection`, or the flat look direction if it is zero. Cast a `workspace:Spherecast` of radius 1.5 along it, excluding the character, and stop 1.5 studs short of a hit. Follow the climb pattern: `MoveState.startClimb`, the `Physics` state, then ease `root.CFrame` along the path over `Config.DashSeconds`. Finish with `MoveState.finishClimb`, the `Freefall` state, and sprint speed along the path. Do not set the `Climbing` attribute, so shooting still works. Ignore `Dash` during a climb.

- [ ] **Step 4: Run tests and commit**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed. Commit: "Add Phase Dash".

### Task 6: Aegis Shell

**Files:**
- Modify: `src/server/AbilityServer.server.luau`, `src/client/Movement.client.luau`

**Interfaces:**
- Consumes: `Target.shield`, `Ability.pushSpeed`, `MoveGrace.give`, `isEnemy`.
- Produces: remote `Push(velocity: Vector3)` to the client.

- [ ] **Step 1: Add the handler**

Set `target.shield` with `shieldHp`, set the `ShieldHp` attribute, and weld a see-through blue sphere around the character. After `duration`, remove it without pushing anyone. Use `CanCollide`, `CanQuery` and `CanTouch` false on the sphere, so shots and the character ignore it.

- [ ] **Step 2: Add the break push**

`onBreak` removes the sphere and finds living enemies within `Config.PushRadius`. Their velocity is away from the owner at `Ability.pushSpeed(tier)`, plus `Config.PushRise` upward. Players get `MoveGrace.give` then `Push`. The dummy gets `AssemblyLinearVelocity` set directly.

- [ ] **Step 3: Add the client push**

On `Push`, change to `Freefall` and set `root.AssemblyLinearVelocity`. Ignore it during a climb or dash.

- [ ] **Step 4: Run tests and commit**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed. Commit: "Add Aegis Shell".

### Task 7: Arc Mine

**Files:**
- Modify: `src/server/AbilityServer.server.luau`, `src/client/Abilities.client.luau`, `src/client/Movement.client.luau`, `src/client/Hud.client.luau`

**Interfaces:**
- Consumes: `Ability.mineTriggered`, `Ability.mineVisibility`, `Ability.slowFactor`, `GunTargets.damage`, `HitConfirm`, `isEnemy`.
- Produces: `workspace.Mines` folder; mine attributes `OwnerId`, `Team` and `Visibility`; character attributes `SlowUntil` and `SlowPct`.

- [ ] **Step 1: Add placement**

Raycast straight down from the root, up to 10 studs, ignoring characters. With no floor, return `false`. Otherwise remove the owner's old mine and place a small anchored disc with `CanCollide`, `CanQuery` and `CanTouch` false. Remove it when the owner's `slots` are rebuilt.

- [ ] **Step 2: Add the trigger**

On each Heartbeat, check each mine against every living enemy with `Ability.mineTriggered`. On a trigger, every enemy within `Config.MineTriggerStuds` takes `damage` and gets `SlowUntil` and `SlowPct`, the owner gets `HitConfirm`, and the mine is destroyed. Show a harmless `Explosion` with `BlastPressure = 0` and `DestroyJointRadiusPercent = 0`.

- [ ] **Step 3: Add the client effects**

For each mine, enemies set `LocalTransparencyModifier` to `1 - Visibility`; the owner and teammates see it in full. `Movement.client` multiplies `humanoid.WalkSpeed` by `Ability.slowFactor`. The HUD shows "Slowed" while it applies.

- [ ] **Step 4: Run tests and commit**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed. Commit: "Add Arc Mine".

### Task 8: River's playtest

- [ ] **Step 1: Give River this checklist, and fix what River reports**

In solo Play, use Y to reach each tier and T to reach each deck:

1. Keys 3, 4 and 5 use the right cards. Bars empty, then refill over the listed cooldown.
2. Phase Dash moves about 16 to 20 studs, stops at walls, and shooting still works. You are not pulled back or given a strike.
3. Overclock fires faster. Your magazine refills when it ends.
4. Recon Pulse outlines the dummy through a wall, only within range.
5. Aegis Shell appears and fades on time. Shoot-testing it needs a Team Test.
6. Arc Mine next to the dummy goes off about 1 second after placing, and hits it for the card's damage. Placing a second removes the first. It does nothing to you.
7. Dying resets every bar, and nothing from the old life carries over.

Then in a two-player Team Test, after committing drafts:

8. Dash camo makes you nearly invisible to the other player, and shorter at Field.
9. The other player's shots hit your shield first. A headshot from an AK-47 or Sniper breaks it and you live.
10. Breaking a shield pushes the other player away. Field pushes less than Prototype.
11. The enemy sees your mine at 20% at Field, 10% at Black-Site and not at all at Prototype. It slows them when triggered.
12. The 0.08s view delay from Phase 2 feels right on a moving target.

- [ ] **Step 2: Run tests**

Run: `lune run tests/run.luau 2>&1 | tail -1`
Expected: 0 failed.

## Risks

| Risk | Mitigation |
| --- | --- |
| A dash feels late on high ping | Server approval is one ping. Predicting the dash on the client is the fallback, but it needs a safe guard warning. |
| Cheats ignore slows, reveal hidden mines or skip recoil | Accepted for movement and visuals. Damage, ammo, cooldowns and shields stay on the server. |
| Physics-state dashes fight the Humanoid | The climb already works this way. |
| Mine trigger checks every target each frame | Few mines and few players per match. |
