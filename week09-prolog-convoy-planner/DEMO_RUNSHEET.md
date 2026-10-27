# Prolog Convoy Planner — Class Demo Run Sheet

## Setup (before class)
```bash
sudo apt install swi-prolog        # or: brew install swi-prolog / winget install SWI-Prolog
swipl --version                    # tested on 9.0.4
swipl convoy_plan.pl               # load the file, opens the ?- prompt
```

## Live demo sequence (~5 min)

| # | Type at `?-` | What to say |
|---|---|---|
| 1 | `situation.` | "The whole problem is **facts**: stock, requirements, routes, capacity. No algorithm yet." |
| 2 | `stock(bsa, Item, N).` then `;` | "Prolog **unifies** and **backtracks**: press `;` and it gives the next answer." |
| 3 | `leg(kuwait, To, Mode, H).` then `;` | "Every leg out of Kuwait. `leg/4` is a **rule** that makes routes two-way and skips closed ones." |
| 4 | `plan.` | "The planner searches the whole state space and returns the **minimum-hours** plan: 30 steps, 64 hours." |
| 5 | `close_route(kuwait, jordan), plan.` | "Air corridor to Jordan is closed. Change one fact and it **re-plans**: 90 hours, now ground through Iraq." |
| 6 | `close_route(kuwait, afghanistan), close_route(uae, afghanistan), plan.` | "Cut every leg into Afghanistan and it **proves** no plan exists. That isn't a crash." |
| 7 | `reset.` | Reopens all routes. |

Shortcut: `demo.` runs steps 1, 4, 5 back to back.

## Talking points: why Prolog fits planning
1. **Declarative.** You state *what* is true (facts) and *what* a legal move is (rules). The engine handles *how* to search.
2. **Backtracking built in.** Unlike the website demo, the original planner mutated state with `assert/retract`, so it couldn't truly backtrack and returned the first plan it found. This version carries state as a term, `s(Loc, Cargo, Stock, Demand)`, so every alternative stays reachable.
3. **Rules = constraints.** Capacity, "don't carry what nobody needs," and route closures are each one line in a rule body.
4. **Optimal, not greedy.** Uniform-cost (Dijkstra) search with a priority queue and a visited set. About 21,000 states are explored in under a second.
5. **Prolog and ML/AI:** Prolog is *symbolic* AI (logic, search, explainable plans). Machine learning is *statistical*. Current neuro-symbolic work pairs them: an LLM or ML model proposes, and a Prolog layer checks against hard constraints. ILP (Inductive Logic Programming) *learns* Prolog rules from examples.

## Scenario defaults (edit the top block of `convoy_plan.pl`)
- **Start/end:** BSA. Capacity is 3 loads. Each load or unload takes 1 hour, and the convoy must return to base.
- **Stock:** BSA has 2× ammunition and 2× food. Kuwait has 2× fuel. UAE has 1× repair parts and 1× medical supplies.
- **Requirements:**
  - Iraq: fuel, ammunition, food
  - Jordan: food, repair parts
  - Afghanistan: ammunition, medical supplies, fuel
- **Routes:**
  - BSA–Kuwait: ground, 2h
  - Kuwait–Iraq: ground, 8h
  - Iraq–Jordan: ground, 10h
  - Kuwait–Jordan: air, 3h
  - Kuwait–UAE: air, 3h
  - UAE–Afghanistan: air, 4h
  - Kuwait–Afghanistan: air, 5h

## Credit
Adapted from Quantum Prolog's container-planning demo:
https://quantumprolog.sgml.net/container-planning-demo/part1.html
