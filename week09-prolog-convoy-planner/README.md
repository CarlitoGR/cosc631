# Week 9 — Prolog for Planning: Military Logistics Convoy Planner

**Assignment:** Research how Prolog can solve planning problems, choose an example, make it work, and demo it in class.

**Example:** This adapts the Quantum Prolog
[container-planning demo](https://quantumprolog.sgml.net/container-planning-demo/part1.html) into a convoy planner.
A single convoy moves supplies between six locations until every location's requirements are met.

## Run
```bash
swipl convoy_plan.pl     # SWI-Prolog 9.x
?- demo.                 # situation -> optimal plan -> route closure + re-plan
```
`DEMO_RUNSHEET.md` has the full in-class query sequence and talking points.

## Model
| Element | Prolog representation |
|---|---|
| Locations | `location/2`: BSA, Kuwait, Jordan, Iraq, Afghanistan, UAE |
| Items | `item/2`: Food, Fuel, Ammunition, Medical supplies, Repair parts |
| Stock / requirements | `stock/3`, `requirement/3` |
| Network | `route/4` (two-way, ground/air, hours); `close_route/2` for closures |
| State | `s(Location, Cargo, Stock, Demand)`, a pure term with no `assert/retract` during search |
| Actions | `step/4`: load, unload, move |
| Search | Uniform-cost (Dijkstra) via `library(heaps)` + visited set (`library(assoc)`) |

## Improvements over the source demo
1. **Real backtracking.** The original changed the database (`assert/retract`) inside the search and committed with cut. It could only return the first plan it found.
2. **Optimal plans.** It returns the minimum-hours plan, not the first feasible one.
3. **Capacity bug fixed.** The original's `Nall < 3` allowed 3 containers against a stated limit of 2.
4. **Re-planning and infeasibility.** You can close routes at runtime. The planner either re-routes or proves no plan exists.

## Results (default scenario)
| Scenario | Result |
|---|---|
| All routes open | 30 steps, **64 h** |
| Kuwait–Jordan closed | **90 h** (ground via Iraq) |
| Both Afghanistan legs closed | **No feasible plan** |
