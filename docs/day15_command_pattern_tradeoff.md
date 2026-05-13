# Command Pattern Tradeoff Assessment

## Summary
A full textbook Command pattern (as in gameprogrammingpatterns.com) is likely valuable long term, but not worth implementing all at once right now.

The current architecture already has a proto-command pipeline:
- command enum in `res://models/input/grid_command.gd`
- command execution in `res://components/movement_controller.gd`
- actor gateway in `res://components/grid_entity.gd`

Given current scope, the best move is a hybrid path: preserve enum-based execution and add a thin command envelope for orchestration layers.

## Benefits of a Real Command Pattern
1. Better source decoupling: player input, enemy AI, scripted events, replay, and networking can all emit a shared command object shape.
2. Cleaner queueing/scheduling: delayed actions, cooldown windows, round systems, and simultaneous resolution are easier with explicit command objects.
3. Better replay/undo foundation: command streams + snapshots support rewind/rollback features.
4. Better observability: command history is easier to log, serialize, and inspect for deterministic debugging.

## Costs and Risks
1. More code surface area: many command classes vs a simple enum + match.
2. Runtime/object churn: short-lived command instances add overhead in GDScript.
3. Higher conceptual overhead: class hierarchies can reduce readability in small systems.
4. Undo complexity: proper undo requires inverse operations or mementos, which is a larger architecture commitment.

## Fit for This Project Right Now
A full execute/undo polymorphic hierarchy is likely overkill for jam velocity.

Recommended approach:
1. Keep execution in `MovementController` and command entry in `GridEntity`.
2. Introduce lightweight command data objects (or a small request struct/resource) for orchestration.
3. Defer full per-command classes with undo semantics until there is a clear need (replay/rollback/complex combat scheduling).

## Practical Staged Plan
1. Near term: add a `CommandRequest` shape (actor id, command type, timestamp, optional payload).
2. Mid term: add a `CommandBus`/scheduler that receives requests from Player + AI and routes to `execute_command`.
3. Later: if needed, evolve into full command classes with `execute()`/`undo()` and state snapshots.

## Decision Rule
Adopt the full Command pattern now only if near-term requirements include one or more of:
- rollback/replay
- macro scripting
- authoritative network reconciliation
- complex simultaneous round resolution with strict deterministic playback

Otherwise, keep the lightweight hybrid and prioritize game features.
