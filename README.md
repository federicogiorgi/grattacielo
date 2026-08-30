# Grattacielo

A clone of Maxis' **SimTower** (Yoot Saito / OPeNBooK, 1994), in Godot 4.7 and
GDScript, for Windows. You own a plot of land and a lot of money; you build a
skyscraper on it, fill it with offices, shops, hotel rooms and cinemas, and
spend the rest of your life discovering that the whole game is really about
elevators.

It is a Godot **project**, not an export — open the folder in Godot 4.7 and
press Play.

```
"D:\Drive\programs\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe" --path .
```

---

## Where the numbers come from

Everything the game charges you, everything it gives you, and every limit it
imposes is taken from the original. Three sources, in order of authority:

1. **`extras/SimTower_manual.txt`** — the scanned user manual. It is the
   authority on *mechanics*: how stress works, what an evaluation means, what
   each facility is for, how the elevator schedule bands behave, and what the
   events do. The OCR lost most of the dollar figures, which is why there is a
   second source.
2. **Measured reference data on the original game** (the Relentless Optimizer
   SimTower reference and two long-standing FAQs) for the *prices, sizes,
   capacities and caps* the OCR dropped.
3. **The Christmas easter egg** — on the last night of the fourth quarter a red
   dot crosses the sky; centre on it and Santa is there in his sleigh, and
   clicking him pays out. Exactly as the user reports of the original describe
   it, and exactly what was asked for.

Every one of those numbers lives in **`data/facility_db.gd`** and
**`data/rules.gd`** and nowhere else. No script in `scripts/` hard-codes a
price, a size, a capacity or a star threshold. `tools/rules_check.gd` asserts
the whole table back, so a stray edit is caught rather than shipped.

### The catalogue

| Facility | Stars | Cost | Size (seg × floors) | Holds | Earns |
|---|---|---|---|---|---|
| Lobby | 1 | 5.000 / segment | 1 × 1 | — | — |
| Empty floor | 1 | 500 / segment | 1 × 1 | — | — |
| Stairs | 1 | 5.000 | 8 × 2 | 21 | — |
| Escalator | 1 | 20.000 | 8 × 2 | 21 | −5.000/qtr |
| Standard elevator | 1 | 200.000 + 80.000/car | 4 wide | 21/car | −10.000 each /qtr |
| Service elevator | 2 | 100.000 + 50.000/car | 4 wide | 21/car | −10.000 each /qtr |
| Express elevator | 3 | 400.000 + 150.000/car | 6 wide | 42/car | −20.000 each /qtr |
| Office | 1 | 40.000 | 9 × 1 | 6 | rent, quarterly |
| Condominium | 1 | 80.000 | 16 × 1 | 3 | sold once, refunded if they leave |
| Single room | 2 | 20.000 | 4 × 1 | 1 | rent, nightly |
| Twin room | 2 | 50.000 | 6 × 1 | 2 | rent, nightly |
| Suite | 2 | 100.000 | 10 × 1 | 2 | rent, nightly |
| Fast food | 1 | 100.000 | 16 × 1 | 30/day | by patron count |
| Restaurant | 3 | 200.000 | 24 × 1 | 40/day | by patron count, doubled |
| Retail shop | 3 | 100.000 | 12 × 1 | 25/day | rent, quarterly |
| Party hall | 3 | 100.000 | 24 × 2 | 50 | per party |
| Cinema | 3 | 500.000 | 31 × 2 | 120 | per screening |
| Housekeeping | 2 | 50.000 | 15 × 1 | 6 staff | −10.000/qtr |
| Security | 2 | 100.000 | 16 × 1 | 4 staff | −20.000/qtr |
| Medical centre | 3 | 500.000 | 26 × 1 | — | — |
| Recycling centre | 3 | 500.000 | 25 × 2 | — | −50.000/qtr |
| Parking space | 2 | 3.000 | 8 × 1 | 1 car | — |
| Parking ramp | 2 | 50.000 | 16 × 1 | — | −10.000/qtr |
| Metro station | 4 | 1.000.000 | 30 × 3 | — | −100.000/qtr |
| Cathedral | 5 | 3.000.000 | 28 × 4 | — | — |

Changing a film costs 300.000 for a new release and 150.000 for a classic. The
fire helicopter costs 500.000. You start with 2.000.000.

### Star ratings

| Rating | Population | Also needs |
|---|---|---|
| 1 star | — | — |
| 2 stars | 300 | — |
| 3 stars | 1.000 | a security office |
| 4 stars | 5.000 | two suites, a satisfied VIP, a medical centre, a recycling centre |
| 5 stars | 10.000 | a metro station |
| **GRATTACIELO** | 15.000 | a cathedral on floor 100 |

### Caps

24 elevator shafts, 8 cars each, 30 floors of travel for a standard shaft; 64
stairs and escalators together; 512 retail units; 512 parking spaces; 10
security offices; 10 medical centres; 16 cinemas and party halls together; one
metro; one cathedral; 20 people you may name and follow.

The lot is **375 segments wide**, and the tower runs **100 storeys up and 10
down**.

---

## What is simulated

- **Time.** A quarter is three days — two weekdays and a weekend. Four quarters
  a year. The clock races through the small hours and crawls through the two
  rush hours, which is exactly when your design decisions show.
- **People.** Everybody in the building is a real object with a schedule, a
  route and a stress level. Office workers arrive in the morning, go to lunch,
  and leave in the evening; residents come and go; hotel guests check in at
  night and out in the morning; housekeepers do their rounds; visitors arrive
  from the street or the metro to shop and see films.
- **Stress** runs 0–300, accrues per minute of walking, queueing and riding,
  and is shed on arrival. Under 80 a person is drawn black, 80–120 pink, over
  120 red — the manual's own thresholds.
- **Evaluation.** A space's quality is `300 − average stress`, adjusted by what
  you charge. Over 200 is an A and the tenants bring a friend to fill a vacant
  space; 150–200 is a B and they stay; under 150 is a C and they leave. That
  loop is the whole game: **a tower nobody can move around in stops growing.**
- **Elevators.** Cars, queues, waiting floors, per-band schedules for weekdays
  and weekends (Local / Express to top / Express to bottom), the "floors closer
  than a moving car" dispatch setting and the departure delay. Express lifts
  stop only at sky lobbies, every fifteenth floor. Nobody changes lift more
  than once in a journey and nobody climbs more than four flights of stairs.
- **Money.** Quarterly rents, nightly hotel rates, daily takings from food by
  patron count, one-off condo sales (refunded in full if the buyer leaves),
  maintenance per quarter, and a finance window that itemises all of it.
- **Noise.** Fast food next to offices, and anything loud next to hotel rooms,
  costs the neighbours stress — the manual's "radial broadcasting", above,
  below and beside.
- **Escalators pool trade**: two commercial floors joined by one share
  customers, as the manual promises.
- **Events.** Fire (which spreads, which security fights according to how close
  they are, and which the helicopter always puts out); the terrorist, who
  demands money and whose bomb always goes off at one o'clock if security does
  not find it; the VIP, who must be kept happy before four stars; buried
  treasure, only if you have underground residences; the wedding in the
  cathedral; and Santa Claus.

  Fire and the terrorist only happen once you have security staff, which is
  what the manual says.

---

## Playing it

- **Left mouse** builds with whatever the tool bar has selected. The lobby, the
  empty floor and parking spaces are **dragged** sideways; elevator shafts are
  **dragged vertically** to set their span; everything else is a click, and you
  can hold and sweep to lay a row of rooms.
- **Right mouse or middle mouse** drags the view. Arrow keys or WASD pan, the
  wheel zooms.
- The three tool-bar mode buttons are the **magnifying glass** (inspect
  anything — a room, a person, a lift), the **bulldozer**, and the **finger**,
  which drags the top or bottom of a lift shaft to lengthen it and switches a
  floor's service off when you click the shaft on that floor.
- Clicking an elevator shaft with the magnifying glass opens the control panel.
  That is where the game is won.
- The **Mappa** window's Eval / Prezzi / Hotel buttons colour the whole tower
  and pause the game, as in the original.
- Space pauses, `M` toggles the map, `F` the finance window.

Saving and loading are on the File menu; the save lives in Godot's `user://`
directory.

---

## Layout

```
data/            every number in the game
  facility_db.gd   the catalogue: prices, sizes, capacities, star gates, caps
  rules.gd         stress, evaluations, patronage, star thresholds, events
  names.gd         people, shop brands, film titles
scripts/core/    the simulation
  tower.gd         the grid, and every rule about what may go where
  facility.gd      one placed thing
  shaft.gd         an elevator shaft, its cars and its schedule
  sim.gd           one person
  sim_engine.gd    schedules, journeys, queues, elevator control
  router.gd        Dijkstra over floors and shafts, with the wait as a cost
  economy.gd       funds and the quarterly ledger
  game_clock.gd    days, quarters, years, and the speed curve
  events.gd        fire, bomb, VIP, treasure, wedding, Santa
  game.gd          the autoload that ties it together
scripts/render/  art.gd (all drawing) and tower_view.gd (the Edit window)
scripts/ui/      the floating windows, built in code
tools/           the checks, and the screenshot mode
extras/          the original manual
```

There are no image or sound files: everything is drawn from primitives, so the
project is self-contained and there is nothing to license.

---

## Checks

```bash
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
```

Three suites, all headless, no window needed:

- **`tools/rules_check.gd`** — every price, size, capacity, star threshold and
  cap asserted against the tables above, plus placement rules, transport rules,
  the economy, and a save/load round trip.
- **`tools/smoke.gd`** — builds a small tower through the real API and runs it
  for a game year.
- **`tools/santa.gd`** — the Christmas easter egg, on its own, because it
  happens for a few minutes once a year and would otherwise never be exercised.

`tools/traffic.gd` is not a test but a diagnostic: it prints an hour-by-hour
census of who is walking, queueing, riding and resting. It is how the two real
simulation bugs so far were found.

To look at the game without playing it:

```bash
Godot_v4.7-stable_win64.exe --path . --windowed --resolution 1360x800 -- --shot 6 out.png
```

which builds a demonstration tower, runs it for six seconds and saves a picture.

---

## Judgement calls

Things the sources did not settle, decided one way and written down so they can
be changed:

- **The interface is in Italian.** The game is called Grattacielo; it seemed
  the right register. Every string is in `data/` and `scripts/ui/`.
- **Money is written `L. 1.234.567`.** Flavour, nothing more — the amounts are
  the original's exactly.
- **Parking unlocks at two stars**, following the manual's tutorial, where the
  parking tools appear alongside the other two-star facilities. One reference
  table puts it at three.
- **Elevators are placed by dragging a span**, rather than the original's
  place-one-floor-then-stretch-with-the-finger. The finger still works, and the
  outcome is identical; dragging is simply less fiddly.
- **The day has seven schedule bands** (00, 07, 09, 12, 15, 18, 21). The
  original's panel shows about six clocks; the exact boundaries are not legible
  in the scan.
- **Rent tiers** are four, as the manual's Pricing view implies (High, Average,
  Low, Very Low), with the middle tier set to the measured quarterly income.
