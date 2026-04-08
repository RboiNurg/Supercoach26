# SuperCoach Data Lookup Build Checklist

This document defines the lookup tables and data layers required to support the NRL SuperCoach decision engine.

The aim is to ensure the engine never has to guess when a value can be looked up. Each week, the system should be able to access a clean current-state snapshot, historical context, and enough forward-looking information to compare short-term tactical moves against the longer season plan.

## 1. Game rules and round state

This is the control layer. Without this, the engine can misjudge what is even possible.

Required fields:

- current round
- current lock status by game and by player
- number of trades remaining
- number of boosts remaining
- squad size and positional slot rules
- scoring format rules
- price change rules
- dual-position eligibility and latest DPP updates
- bye round structure
- Origin-affected rounds
- finals or head-to-head calendar if relevant to your league

Why it matters:

The engine needs to know whether a move is legal, whether waiting has value, and how much a trade is worth now versus later.

## 2. Master player table

This is the core object. Every player decision flows from here.

For every player in the game:

- player_id
- full name
- team
- positions
- current price
- breakeven
- current season average
- 3-round average
- 5-round average
- ownership percentage
- total points
- games played
- status: active, injured, suspended, omitted, named on bench, reserve, etc.
- injury detail and expected return if available
- role tag: fullback, halfback, edge, middle, hooker, bench utility, etc.
- goal-kicking status
- starting status vs bench status
- minute history
- points history by round
- price history by round

Why it matters:

This is the universal lookup for buy, hold and sell logic.

## 3. Player scoring component history

Do not just store raw points. You want the ingredients, so the engine can detect whether a score is repeatable or fluky.

By player and round:

- total score
- base stats
- base attack if available
- tries
- try assists
- linebreaks
- linebreak assists
- tackle busts
- offloads
- goals
- kick metres
- tackles made
- missed tackles
- run metres
- errors
- sin bin / send off / HIA disruptions
- minutes played
- starting position that round

Derived fields:

- base per minute
- attack reliance ratio
- volatility score
- floor score estimate
- ceiling score estimate
- role-adjusted average
- points per minute

Why it matters:

The engine should prefer sustainable scoring profiles unless it has a specific reason not to.

## 4. Team list and role certainty lookup

This is separate from the player table because it changes rapidly and often matters more than historical scoring.

For each player in each upcoming round:

- whether named
- jersey number
- starting or bench
- listed position
- actual recent role
- likely minutes
- likelihood of role change
- likelihood of late omission
- likely replacement if a late change happens
- whether player is covering an injured teammate
- whether another player returning threatens job security

Why it matters:

Many bad trades come from buying points that were created by a temporary role.

## 5. Fixture and matchup table

This is the forward-looking schedule model.

By team and upcoming round:

- opponent
- venue
- home/away
- days rest
- travel burden if relevant
- short turnaround flag
- opponent recent form
- team recent form
- projected game total if you can infer it
- projected team scoring environment
- opponent defensive weakness by position
- opponent attacking weakness by position
- team pace / style indicators if useful
- bye flag
- major outs for opponent
- major outs for own team

Derived fields:

- matchup rating by player
- matchup rating by team
- next 2 rounds difficulty
- next 3 rounds difficulty
- next 5 rounds difficulty
- schedule swing indicator

Why it matters:

A player is not just a player. He is also the fixture run attached to him.

## 6. Team performance context

This helps the engine distinguish individual form from environment.

By team and round:

- points scored
- points conceded
- tries scored
- tries conceded
- linebreaks for and against
- possession share if available
- territory indicators if available
- completion rate if available
- attacking trend over last 3 and 5 rounds
- defensive trend over last 3 and 5 rounds
- left-edge and right-edge vulnerability if available
- middle defensive weakness if available

Why it matters:

A decent player in a hot attack against a weak edge is different from the same player in a dysfunctional team.

## 7. Cash generation and price movement model

This needs its own lookup because it drives trade timing.

By player:

- starting price
- current price
- price change last round
- cumulative cash generation
- projected price rise next round
- projected price fall next round
- breakeven trend
- number of games until peak cash estimate
- cash cow maturity status: rising, near peak, peaked, stalled
- keeper / cash cow / stepping-stone / trap classification

Why it matters:

The engine needs to know not just who is good, but when to buy and when to sell.

## 8. Your squad table

This should be richer than just "my team".

For each player in your squad:

- acquisition round
- acquisition price
- current price
- profit or loss
- current role security
- keeper status
- sell urgency
- cover value
- captaincy value
- bye usefulness
- DPP flexibility usefulness
- injury / suspension risk
- whether currently locked
- whether selected this week
- whether on field / bench / NPR
- projected score this week
- projected score next 3 weeks
- projected value change next 3 weeks

Why it matters:

The engine should judge every trade as current player versus replacement, not in isolation.

## 9. Opponent squad and behaviour history

Since opponent behaviour can be inferred from league history and cash history, this is a major edge.

For each opponent and by round:

- full squad history
- trade history if inferable
- boost usage history
- captain history
- vice-captain patterns if inferable

## 10. Rolling lockout deception planner spec

This section is the hard spec for the in-app `Rolling Lockout Deception Planner`.

The planner is not a generic optimiser. Its purpose is to help set a legal fake-looking team before the first game, then give exact step-by-step changes so the real highest-scoring team lands in place under rolling lockout.

### Planner intent

The planner must do all of these at once:

- maximise likely scoring from the final counting side
- preserve legal rolling-lockout flexibility
- avoid revealing the true team shape too early
- respect already-locked players and already-closed games
- keep captaincy, vice-captaincy, field slots, bench slots and reserves legally consistent at every step
- produce instructions that a human can literally follow on the SuperCoach site

### Planner inputs

The planner must read and use:

- current squad
- current player prices
- current player position eligibility
- kickoff time for every player this round
- current round lock state
- projected scoring / form / matchup values
- selected trades, up to 3
- selected VC/C combination
- current legal team structure:
  - 14 on-field scorers
  - 4 reserve scorers
  - all remaining squad members on bench in non-reserve state

### Planner outputs

The planner must generate four linked outputs:

1. Confirmed post-trade team

- trades selected by the user
- traded-in player initially inherits the traded-out player's current site slot if legal
- if not legal, planner must explicitly state where the incoming player is first parked

2. Bogus starting setup

- full squad state, not just active players
- every player must appear exactly once
- every player must be in one of:
  - on-field slot
  - bench slot
- reserve state must be explicit for every bench player
- bogus captain and bogus vice-captain must be explicit

3. Exact move schedule

- one row per lock window / game
- each row must start from the previous row's resulting state
- each row must only make moves that are still legal at that moment
- each row must explicitly list:
  - players locking now
  - exact trade if a trade happens here
  - exact paired swaps only
  - captaincy change
  - reserve changes
  - why this is the latest safe move point

4. Final intended counting side

- full squad state again, not just the 14 field players
- the 14 on-field scorers must be explicit
- the 4 reserve scorers must be explicit
- all remaining bench players must still be shown
- captain, VC, reserve flags and slots must all be visible

### Hard rules

These are non-negotiable rules. If any are broken, the plan is wrong.

#### 10.1 Locked-player immutability

- once a player's game has locked, that player cannot be moved again
- if `Paseka` locks on Friday, the planner must never suggest moving him on Sunday
- if a player was already moved into a scoring slot before kickoff, later rows must treat that position as fixed unless another still-unlocked interchangeable player is legally being swapped

#### 10.2 Stateful planning

- planner rows must be chained
- row 2 must start from row 1 result
- row 3 must start from row 2 result
- planner must never silently re-optimise from scratch mid-round

#### 10.3 No vague bench moves

- `player -> bench` on its own is invalid output
- every move must be exact:
  - `Swap FRF2 Rudolf with Bench 2 Haas`
  - `Trade Walsh -> Edwards into FLX`
- if a player leaves a slot, the output must show exactly who fills it

#### 10.4 Bench state must be explicit

- all non-field players must have a numbered bench slot:
  - `Bench 1`, `Bench 2`, ...
- if a field player is swapped with a bench player, the former field player takes that bench slot
- reserve state must follow the slot/bench state and then be explicitly updated if changed

#### 10.5 Reserve legality

- there can only ever be 4 reserve scorers
- the 4 reserve scorers must be the highest projected scoring bench options available in the final reachable state
- if a reserve-carrying player is swapped to field, reserve ownership travels to the bench player replacing him until explicitly changed
- reserve changes must be shown in the schedule

#### 10.6 Position legality

- every intermediate step must respect SuperCoach positional rules
- DPP players may be used to support legal swaps
- FLEX logic must also remain legal at each step
- traded-in players must fit the slot they are placed in

#### 10.7 Captaincy legality

- there must always be a current captain and a current VC
- if a traded-out player was holding `C` or `VC`, the same row must repair that
- bogus captaincy and real captaincy are separate concepts, but each planner state must still be internally legal

#### 10.8 Traceability

- user must be able to read the schedule top to bottom without guessing
- no row may imply hidden reshuffles outside what is printed

#### 10.9 Reachable final-state logic

- the planner must not optimise against an ideal end-state that later becomes unreachable
- before each lock window, it must recompute the best reachable final side using:
  - already locked field players fixed in place
  - already locked bench players excluded from future field slots
- if a Friday player is still on field when Friday locks, every later target state must respect that

### Specific failure examples to guard against

These are known bad behaviours the planner must never produce.

#### Failure A: moving a player after he already locked

Bad:

- Friday: `Paseka` remains on field
- Sunday: planner says `Swap FRF1 Paseka -> Hau`

Why bad:

- `Paseka` was already locked earlier in the round
- planner has ignored lock chronology

#### Failure B: vague bench destination

Bad:

- `2RF1: Colquhoun -> bench`

Why bad:

- this does not say which bench slot he goes to
- it does not say who takes `2RF1`
- it gives no reserve consequence

#### Failure C: mid-round silent reshuffle

Bad:

- Thursday row changes several Saturday/Sunday placeholders even though those players are not involved in the current lock

Why bad:

- planner is re-solving from scratch instead of preserving state
- this makes the schedule unreadable and unrealistic

#### Failure D: captaincy orphan

Bad:

- incumbent captain is traded out
- planner only says `Set VC to Edwards`
- no actual captain remains

Why bad:

- every planner state must have both a valid captain and VC

### Deliverables checklist

The planner is only complete when all items below are true.

- trades are confirmed before VC/C selection
- VC/C recommendations are built from the post-trade team
- bogus starting setup shows all squad players
- bogus starting setup shows all 4 reserve scorers
- bogus starting setup shows bogus captain and bogus VC
- exact move schedule is one row per lock window
- every schedule row uses the previous row's resulting state
- every schedule row targets the best reachable final state from that moment, not a stale ideal state
- no row moves already-locked players
- no row contains a vague `player -> bench` instruction
- every swap shows both source and destination
- reserve changes are explicit and legal
- final intended counting side shows all squad players
- final intended counting side clearly marks:
  - on-field scorers
  - 4 reserve scorers
  - captain
  - VC
- planner remains legal under DPP / FLEX / trade scenarios

### Acceptance test cases

These cases should be manually checked whenever planner logic changes.

#### Case 1: no-trade round

- planner should still produce bogus setup, schedule and final side
- schedule should not invent unnecessary moves

#### Case 2: simple same-position trade

- example: `Walsh -> Edwards`
- incoming player should inherit or be parked cleanly
- no captaincy orphan
- no later impossible FLB/FLEX movement

#### Case 3: early-lock scorer on reserve

- if a Thursday player is a true final scorer but starts hidden on reserve
- planner must bring him in before that lock
- planner must not try to move him later

#### Case 4: reserve carry-over

- if a reserve-on player is swapped into the field
- the outgoing field player must inherit that bench slot
- reserve state must be updated explicitly

#### Case 5: DPP bridge case

- a legal DPP-enabled swap sequence should be preserved
- planner must not break slot legality at any intermediate step

### Coding note

When changing planner logic, code should be reviewed against this exact order:

1. build legal post-trade squad
2. build bogus starting state from that squad
3. preserve full state:
   - field slots
   - bench slots
   - reserve flags
   - captaincy
4. step game-by-game through lock windows
5. only make exact legal changes needed at that window
6. emit final full squad state

If the planner cannot express a move as an exact legal state transition, it should not output that move.
- cash history
- positional weaknesses
- tendency to hold trades or spend aggressively
- tendency to chase pods or play safely
- likely current cash available
- likely future trade capacity
- likely forced trades this week
- likely target players based on affordability and structure
- likely captaincy options this week

Derived fields:

- probability opponent buys player X
- probability opponent sells player Y
- probability opponent can cover bye/injury issues
- expected opponent score this week
- expected opponent volatility
- whether you should block, mirror, or differentiate

Why it matters:

Head-to-head strategy is not just about maximising your own projected points. It is about beating a specific opponent at acceptable long-term cost.

## 10. League-wide ownership and movement signals

This is the crowd context.

By player and round:

- ownership percentage
- top-ranked ownership if accessible
- league-specific ownership if accessible
- net trade-ins
- net trade-outs
- captaincy popularity if inferable
- pod status
- anti-pod risk score
- block value score

Why it matters:

The engine should know when a player is a necessary shield and when he is a leverage opportunity.

## 11. Availability and risk table

This is the layer that prevents blind spots.

By player:

- injury status
- suspension status
- judiciary risk if relevant
- return timeline
- benching / omission risk
- minute reduction risk
- role competition risk
- rest risk
- Origin selection risk
- bye exposure
- late mail sensitivity

Why it matters:

A move with a high expected score but high non-playing risk is not equivalent to a stable scorer.

## 12. Captaincy and VC table

Treat this as its own subsystem.

By player and round:

- projected captain score
- floor
- ceiling
- volatility
- matchup-adjusted ceiling
- historical score against opponent if useful
- role certainty
- blow-up probability
- safe captain score
- aggressive captain score

Why it matters:

Captaincy is one of the biggest weekly edges and should not be hidden inside general player projections.

## 13. Trade candidate comparison table

This is where the engine actually starts making choices.

For every plausible trade-in and trade-out pairing:

- immediate point gain this round
- expected point gain over 3 rounds
- expected point gain over 5 rounds
- expected value gain over 3 rounds
- structural impact
- bye impact
- captaincy impact
- cover impact
- DPP flexibility impact
- risk impact
- opponent-specific impact
- trade efficiency score
- urgency score

Why it matters:

The engine should compare packages, not just rank players.

## 14. Structure health table

This is one of the most important and most overlooked lookups.

At squad level:

- number of keepers by position
- number of cash cows by position
- number of dead spots
- number of playable reserves
- number of active NPR risks
- DPP flexibility count
- captaincy depth
- bye round coverage
- Origin disruption exposure
- injury exposure
- average projected points by slot
- weakest slot ranking
- most urgent upgrade path
- most urgent cash-out path

Why it matters:

A flashy trade can still be wrong if it weakens your overall structure.

## 15. Scenario table for during-round decisions

Because the data is refreshed before each game, this becomes a real advantage.

For each refresh point:

- locked players
- unlocked players
- updated team news
- updated opponent likely score
- updated matchup context
- updated captaincy options
- best no-trade option
- best one-trade option
- best two-trade option
- best boost option
- marginal gain of acting now versus waiting
- long-term penalty of acting now versus waiting

Why it matters:

The engine should ask: now that new information exists, is the extra edge worth the season cost?

## 16. Long-horizon planning table

This stops short-term optimisation from wrecking the season.

By future week horizon:

- projected trades remaining
- projected boosts remaining
- planned upgrade targets
- likely sell targets
- cash generation pipeline
- future bye weakness
- future Origin weakness
- final-team completion estimate
- weeks until full gun team estimate
- runway score for overall rank
- runway score for head-to-head finals

Why it matters:

The engine needs a memory of where it is trying to go.

## Minimum viable lookup stack

If building in the smartest order, start with:

1. master player table
2. player scoring component history
3. team list and role certainty
4. fixture and matchup table
5. cash generation and price movement model
6. your squad table
7. opponent squad and behaviour history
8. structure health table
9. trade candidate comparison table
10. scenario table for during-round decisions

That is enough to make real decisions without waiting for every possible extra layer.

## The cleanest way to think about it

The engine needs six core question groups, and each lookup should serve one of them.

### Can this player score?
- scoring history
- role
- minutes
- team context
- matchup

### Can this player make money?
- price
- breakeven
- price trend
- role stickiness

### Can this player survive?
- injury
- suspension
- job security
- Origin
- byes

### Does this move help my structure?
- squad table
- structure health
- DPP
- captaincy depth

### Does this move beat this week’s opponent?
- opponent history
- likely trades
- likely captaincy
- matchup

### Is this still right for the season?
- long-horizon planning
- trade preservation
- upgrade roadmap

If a data lookup does not materially help answer one of those, it is probably secondary.

## Recommended build order

If you want the sharpest order for script development:

### Phase 1: core truth tables
- game rules and round state
- master player table
- fixture table
- your squad history
- opponent squad history

### Phase 2: decision-quality enrichments
- player scoring component history
- role/minutes certainty
- cash generation model
- team performance context
- availability/risk table

### Phase 3: engine outputs
- structure health table
- captaincy table
- trade candidate comparison table
- scenario table
- long-horizon planning table

## Important design warning

Do not only build "best player" tables.
That will lead to bad decisions.

Build tables that preserve:

- time
- uncertainty
- structure
- opportunity cost
- opponent context

The engine is not trying to answer "who is best?"
It is trying to answer "what is the best move, right now, given all constraints?"
