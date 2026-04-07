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
