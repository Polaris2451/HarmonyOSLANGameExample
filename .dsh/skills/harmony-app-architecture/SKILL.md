---
name: harmony-app-architecture
description: Use when structuring a HarmonyOS application or reviewing its design - module boundaries (entry/HAR/HSP), layering and dependency direction, state ownership, the networking seam, error model, concurrency, configuration, and testability. Targets HarmonyOS 6.0.0 / API 26 stage model and this server-plus-client course project.
whenToUse: Starting a new module or feature area, deciding where code belongs, reviewing a design, or refactoring a growing HarmonyOS app.
---

# HarmonyOS application architecture

Architecture is the set of decisions that are expensive to reverse. Make them explicitly, in writing, and keep the dependency arrows pointing one way.

## Module types and boundaries

| Kind | What it is | Use for |
|---|---|---|
| **entry** | the HAP users install; holds abilities/pages and the app's shell | exactly one entry; ability lifecycle and routing only |
| **HAR** (static) | compiled into every consumer | shared UI, domain and data code; the default for feature modules |
| **HSP** (shared) | one copy at runtime, loaded on demand | large shared runtime with its own state; use when HAR duplication hurts |
| **test** | unit (`src/test`) and instrumented (`src/ohosTest`) | hypium suites |

The course project starts as one `entry` module. Split only when a boundary is *already* painful:

1. **`core` (HAR)** - pure model, protocol, no ArkUI, no platform imports. Unit-testable under plain Node semantics.
2. **`net` (HAR)** - transport, codec, reconnect, depends on `core` only.
3. **`feature-tetris`, `feature-draw` (HAR)** - game UI + view models, depend on `core` and `net`.
4. **`entry`** - abilities, routing, DI wiring; the only module that knows all the others.

Dependency direction is **inward**: features never import each other, and nothing imports `entry`. `oh-package.json5` `dependencies` is the enforcement mechanism - if an import would need a new dependency, the boundary is being crossed.

## Layering inside a module

~~~
pages/        ArkUI components only: bind state, call a view model. No network, no parsing.
viewmodel/    @ObservedV2 stores: expose state + intents, own no transport details.
domain/       pure functions and rules: gravity, scoring, guess normalization. No async, no I/O.
data/         transport clients, codecs, persistence. Owns retries and connection state.
model/        interfaces shared with the server: Envelope, PlayerState, BoardState.
~~~

A component that parses JSON or opens a socket has already broken the layering; move that call into `data/` and expose a method.

## State ownership

Write down, once, which layer owns each piece of state:

- **Server-authored** (board, scores, phase, roster) - owned by the server; the client stores the latest snapshot and never mutates it locally except as an optimistic placeholder that is overwritten.
- **Session-scoped** (player id, room code, connection status) - `AppStorage` / `PersistentStorage`, read via `@StorageLink`.
- **Screen-local** (dialog open, selected tab) - `@State` / `@Local`.
- **Derived** (can I guess right now? is it my turn?) - `@Computed`, never stored.

One store per concern. A single god store is how a two-game app becomes unmaintainable in week three.

~~~typescript
@ObservedV2
export class RoomStore {
  @Trace phase: Phase = 'lobby';
  @Trace players: PlayerState[] = [];
  @Trace board: number[] = new Array<number>(200).fill(0);
  @Trace latencyMs: number = 0;
}
~~~

## The networking seam

Design it as an interface, so games never see a socket:

~~~typescript
export interface Transport {
  connect(url: string): Promise<void>;
  send(env: Envelope): void;
  onFrame(handler: (env: Envelope) => void): void;
  onStatus(handler: (s: ConnStatus) => void): void;
  close(): void;
}
~~~

Behind it: one implementation for `webSocket`, one in-memory fake for tests, one scriptable fake for UI states. The `onStatus` union (`idle | connecting | open | reconnecting | closed`) is what drives the connection banner in the UI - do not let each page invent its own.

Connection policy belongs here and nowhere else: exponential backoff with jitter, a bounded queue for frames sent while reconnecting, and a hard "give up after N minutes" that surfaces an actionable error.

## Error model

Two audiences, so two representations:

- **Expected, user-actionable** (server down, room full, wrong version) -> a typed failure with a `code` and a rendered sentence. The UI shows a retry.
- **Unexpected** (parse failure, impossible state) -> `hilog.error` with the raw payload plus a generic message. Never show a stack trace to a student.

Do not throw strings, and do not swallow catches. `catch (e) { }` with an empty body is the most expensive line in the codebase.

~~~typescript
export class GameError extends Error {
  constructor(readonly code: GameErrorCode, message: string, readonly detail?: string) { super(message); }
}
~~~

## Concurrency

- UI thread: rendering and cheap state updates only.
- `taskpool` with `@Concurrent` functions for CPU-heavy pure work (replay analysis, big board scans).
- The network callback thread: enqueue into the store; never touch ArkUI objects from a socket callback.
- Every timer and subscription has an owner and is released in `aboutToDisappear`.

## Configuration and environments

- `build-profile.json5` products/flavors for dev vs demo builds.
- Server address is **configuration, not a constant**: read from `resources/rawfile/config.json` so changing classes does not require a code edit and a rebuild.
- `signingConfigs` stays empty for emulator work; add a signing config only when a real device demands it.

## Testability

- `core/` and `domain/` are pure -> hypium unit tests with no device (`entry/src/test`).
- `Transport` fake -> drive the whole UI without a server; assert every `ConnStatus` renders.
- One instrumented test (`entry/src/ohosTest`) that boots the ability and asserts the first screen renders.
- A protocol replay harness: JSONL frames in, store state out, so a server bug becomes a deterministic unit test.

## Decisions to record

Keep a short `docs/adr/NNN-title.md` per irreversible choice, with: context, decision, consequences, alternatives rejected. The four that will actually be asked about in review are the topology (server vs P2P), the tick rate, the state-management generation (V1 vs V2), and the module split.

## Review checklist

- [ ] Dependency direction is inward; features do not import each other.
- [ ] ArkUI components contain no `fetch`/socket/JSON parsing.
- [ ] Every piece of state has exactly one owner, named in writing.
- [ ] Games depend on `Transport`, not on `webSocket`.
- [ ] Connection status is one shared union, not per-page booleans.
- [ ] Errors are typed; no empty catch blocks; no raw exceptions in the UI.
- [ ] Server address comes from configuration.
- [ ] `core`/`domain` have unit tests that run without a device.
