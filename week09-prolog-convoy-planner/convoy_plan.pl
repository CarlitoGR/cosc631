/*  convoy_plan.pl -- Military logistics convoy planner (SWI-Prolog)

    Adapted from the Quantum Prolog "container planning" demo
    (https://quantumprolog.sgml.net/container-planning-demo/part1.html).

    One convoy moves supply loads between locations so that every
    requirement is met. Improvements over the original demo:
      * Pure state (no assert/retract inside the search), so backtracking works.
      * Uniform-cost search (Dijkstra) over states: returns the MINIMUM-HOURS
        plan, not just the first plan that happens to work.
      * Correct capacity check (the original allowed 3 loads with a cap of 2).
      * Route closures for live re-planning.

    Usage:
        $ swipl convoy_plan.pl
        ?- demo.                      % full walkthrough
        ?- plan.                      % plan with current data
        ?- close_route(kuwait, iraq), plan.
        ?- reset.                     % reopen all routes
*/

:- use_module(library(heaps)).
:- use_module(library(assoc)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- dynamic closed/2.

% ============================================================================
% SCENARIO DATA -- edit this block to change the problem
% ============================================================================

%!  location(?Id, ?Name)
location(bsa,         'Brigade Support Area').
location(kuwait,      'Kuwait').
location(jordan,      'Jordan').
location(iraq,        'Iraq').
location(afghanistan, 'Afghanistan').
location(uae,         'UAE').

%!  item(?Id, ?Name)   -- general supply categories
item(food,         'Food').
item(fuel,         'Fuel').
item(ammunition,   'Ammunition').
item(medical,      'Medical supplies').
item(repair_parts, 'Repair parts').

%!  stock(?Location, ?Item, ?Loads)   -- loads on hand at start
stock(bsa,    ammunition, 2).
stock(bsa,    food, 2).
stock(kuwait, fuel, 2).
stock(uae,    repair_parts, 1).
stock(uae,    medical, 1).

%!  requirement(?Location, ?Item, ?Loads)   -- loads required
requirement(iraq,        fuel, 1).
requirement(iraq,        ammunition, 1).
requirement(iraq,        food, 1).
requirement(jordan,      food, 1).
requirement(jordan,      repair_parts, 1).
requirement(afghanistan, ammunition, 1).
requirement(afghanistan, medical, 1).
requirement(afghanistan, fuel, 1).

%!  route(?A, ?B, ?Mode, ?Hours)   -- two-way legs
route(bsa,    kuwait,      ground, 2).
route(kuwait, iraq,        ground, 8).
route(iraq,   jordan,      ground, 10).
route(kuwait, jordan,      air,    3).
route(kuwait, uae,         air,    3).
route(uae,    afghanistan, air,    4).
route(kuwait, afghanistan, air,    5).

convoy_start(bsa).
convoy_capacity(3).            % max loads on the convoy at one time
handling_hours(1).             % hours per load/unload action
return_to_base(true).          % plan must end back at the start location

% ============================================================================
% NETWORK
% ============================================================================

%!  leg(+From, -To, -Mode, -Hours) is nondet.
%   Routes are two-way unless closed.
leg(A, B, Mode, Hours) :-
    (   route(A, B, Mode, Hours)
    ;   route(B, A, Mode, Hours)
    ),
    \+ closed(A, B),
    \+ closed(B, A).

%!  close_route(+A, +B) is det.
close_route(A, B) :-
    (   closed(A, B) -> true ; assertz(closed(A, B)) ),
    format("~n  ** ROUTE CLOSED: ~w <-> ~w **~n", [A, B]).

%!  reset is det.
reset :-
    retractall(closed(_, _)),
    format("~n  All routes open.~n").

% ============================================================================
% STATE:  s(Location, Cargo, Stock, Demand)
%   Cargo  : sorted list of items on the convoy, e.g. [ammunition, fuel]
%   Stock  : sorted list of (Loc-Item)-N, N > 0
%   Demand : sorted list of (Loc-Item)-N, N > 0
% ============================================================================

initial_state(s(Start, [], Stock, Demand)) :-
    convoy_start(Start),
    findall((L-C)-N, (stock(L, C, N), N > 0), S0),
    msort(S0, Stock),
    findall((L-C)-N, (requirement(L, C, N), N > 0), D0),
    msort(D0, Demand).

goal(s(Loc, [], _, [])) :-
    (   return_to_base(true)
    ->  convoy_start(Loc)
    ;   true
    ).

% ============================================================================
% ACTIONS:  step(+State, -Action, -NextState, -Hours)
% ============================================================================

% LOAD one unit at the current location.
% Pruning: never carry more of an item than is still required somewhere.
step(s(L, Cargo, Stock, Demand), load(C, L), s(L, Cargo1, Stock1, Demand), H) :-
    convoy_capacity(Cap),
    length(Cargo, Onboard),
    Onboard < Cap,
    member((L-C)-_, Stock),
    still_needed(C, Demand, Needed),
    count(C, Cargo, Carried),
    Carried < Needed,
    decrement(L-C, Stock, Stock1),
    msort([C|Cargo], Cargo1),
    handling_hours(H).

% UNLOAD one unit where it is required.
step(s(L, Cargo, Stock, Demand), unload(C, L), s(L, Cargo1, Stock, Demand1), H) :-
    sort(Cargo, Distinct),
    member(C, Distinct),
    memberchk((L-C)-_, Demand),
    selectchk(C, Cargo, Cargo1),
    decrement(L-C, Demand, Demand1),
    handling_hours(H).

% MOVE along an open leg.
step(s(L, Cargo, Stock, Demand), move(L, To, Mode, H), s(To, Cargo, Stock, Demand), H) :-
    leg(L, To, Mode, H).

still_needed(C, Demand, Total) :-
    aggregate_all(sum(N), member((_-C)-N, Demand), Total).

count(X, List, N) :-
    include(==(X), List, Xs),
    length(Xs, N).

decrement(Key, List0, List) :-
    selectchk(Key-N, List0, Rest),
    N1 is N - 1,
    (   N1 =:= 0
    ->  List = Rest
    ;   msort([Key-N1|Rest], List)
    ).

% ============================================================================
% SEARCH: uniform-cost (Dijkstra) over states -> minimum-hours plan
% ============================================================================

%!  solve(-Plan, -Hours, -Expanded) is semidet.
solve(Plan, Hours, Expanded) :-
    initial_state(S0),
    list_to_heap([0-node(S0, [])], Q0),
    empty_assoc(Visited0),
    ucs(Q0, Visited0, 0, RevPlan, Hours, Expanded),
    reverse(RevPlan, Plan).

ucs(Q0, Visited, N, Path, Cost, Expanded) :-
    get_from_heap(Q0, G, node(S, P), Q1),
    (   goal(S)
    ->  Path = P, Cost = G, Expanded = N
    ;   get_assoc(S, Visited, _)
    ->  ucs(Q1, Visited, N, Path, Cost, Expanded)
    ;   put_assoc(S, Visited, true, Visited1),
        findall(G1-node(S1, [A|P]),
                ( step(S, A, S1, H),
                  \+ get_assoc(S1, Visited1, _),
                  G1 is G + H
                ),
                Children),
        foldl(push, Children, Q1, Q2),
        N1 is N + 1,
        ucs(Q2, Visited1, N1, Path, Cost, Expanded)
    ).

push(P-N, H0, H) :- add_to_heap(H0, P, N, H).

% ============================================================================
% OUTPUT
% ============================================================================

%!  plan is det.
plan :-
    format("~n=== CONVOY OPORD ===~n"),
    (   solve(Plan, Hours, Expanded)
    ->  print_plan(Plan, 0, 1),
        length(Plan, Steps),
        format("~n  Mission complete: ~w steps, ~w hours (~w states searched)~n",
               [Steps, Hours, Expanded])
    ;   format("~n  NO FEASIBLE PLAN with current routes and capacity.~n")
    ).

print_plan([], _, _).
print_plan([A|As], T0, I) :-
    action_hours(A, H),
    T is T0 + H,
    describe(A, Text),
    format("  ~|~t~d~2+. [H+~|~t~d~2+]  ~w~n", [I, T, Text]),
    I1 is I + 1,
    print_plan(As, T, I1).

action_hours(move(_, _, _, H), H) :- !.
action_hours(_, H) :- handling_hours(H).

describe(load(C, L), Text) :-
    item(C, Name),
    format(atom(Text), "LOAD     ~w at ~w", [Name, L]).
describe(unload(C, L), Text) :-
    item(C, Name),
    format(atom(Text), "DELIVER  ~w to ~w", [Name, L]).
describe(move(A, B, Mode, H), Text) :-
    upcase_atom(Mode, M),
    format(atom(Text), "MOVE     ~w -> ~w  [~w, ~wh]", [A, B, M, H]).

%!  situation is det.  -- print the starting picture
situation :-
    format("~n=== SITUATION ===~n"),
    convoy_start(S), convoy_capacity(Cap),
    format("  Convoy at ~w, capacity ~w loads~n~n  Stock on hand:~n", [S, Cap]),
    forall(stock(L, C, N), (item(C, Name), format("    ~w: ~w x ~w~n", [L, N, Name]))),
    format("~n  Requirements:~n"),
    forall(requirement(L, C, N), (item(C, Name), format("    ~w: ~w x ~w~n", [L, N, Name]))),
    format("~n  Routes (two-way):~n"),
    forall(route(A, B, M, H),
           (   (closed(A, B) ; closed(B, A))
           ->  format("    ~w <-> ~w  ~w ~wh  ** CLOSED **~n", [A, B, M, H])
           ;   format("    ~w <-> ~w  ~w ~wh~n", [A, B, M, H])
           )).

%!  demo is det.  -- the in-class walkthrough
demo :-
    reset,
    situation,
    plan,
    close_route(kuwait, jordan),
    plan,
    reset.
