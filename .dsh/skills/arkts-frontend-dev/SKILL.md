---
name: arkts-frontend-dev
description: Use when writing or reviewing ArkTS / ArkUI application code in this HarmonyOS project - component and state-management patterns, strict ArkTS language rules, resources, async and concurrency, networking clients, and the build/run loop. Targets HarmonyOS 6.0.0 / API 26, stage model.
whenToUse: Writing ArkTS code, adding a page or component, wiring state, calling an HTTP/WebSocket API, or debugging a build/runtime failure.
---

# ArkTS frontend development

ArkTS is **not** TypeScript with a different name. It is a statically typed, structurally restricted subset; code that compiles under `tsc` can still be rejected by the ArkTS compiler. Getting these rules right on the first pass decides whether the iteration loop is fast or miserable.

## Language rules that actually break builds

| Forbidden | Write instead |
|---|---|
| `any`, `unknown`, `object` as a type | a real `interface` / `class` / concrete union |
| Structural typing (assigning a shape-compatible object) | implement the declared `interface` explicitly |
| Untyped object literals `{ a: 1 }` | `const p: Point = { x: 1, y: 2 }` |
| Dynamic property access `obj[key]` | a `Map<K, V>` or an explicit `switch` |
| `Function` / `CallableFunction` types | `(x: number) => void` |
| `delete`, `with`, `eval`, `arguments` | explicit nulling / rest params |
| `as` casts between unrelated types | type guards (`if (e instanceof X)`) |
| Class fields without an initializer | initialize inline or in the constructor |

Declare the wire format once and reuse it on both sides:

~~~typescript
export interface NetEnvelope {
  v: number;        // protocol version
  t: string;        // message type
  seq: number;      // monotonically increasing sender sequence
  room?: string;
  payload: string;  // JSON-encoded typed body
}
~~~

## Components

~~~typescript
@Entry
@Component
struct RoomPage {
  @State code: string = '';

  aboutToAppear(): void { /* subscribe */ }
  aboutToDisappear(): void { /* MUST unsubscribe and close sockets */ }

  build() {
    Column({ space: 12 }) {          // exactly one root node
      Text($r('app.string.room_title')).fontSize($r('app.float.font_title'))
      Button($r('app.string.join')).onClick(() => { this.join(); })
    }
    .width('100%').height('100%')
  }

  private join(): void { /* ... */ }
}
~~~

`build()` is a **pure description**: no `if` / `for` / `await` statements that produce nodes, no side effects, no local node variables. Conditionals appear only as ArkUI conditional syntax inside `build`, and loops use `ForEach` / `LazyForEach`.

Every `ForEach` needs a key generator, and **the key must contain every mutable field the row renders**:
ArkUI rebuilds an item only when its key changes, so a key of just `item.id` freezes the row forever.

~~~typescript
// WRONG: the score never updates, because the key never changes
ForEach(this.players, (p: Player) => { Row(p) }, (p: Player) => p.id)

// RIGHT: changing the score or the flag rebuilds the row
ForEach(this.players, (p: Player) => { Row(p) },
  (p: Player) => p.id + '/' + p.score.toString() + '/' + (p.guessed ? '1' : '0'))
~~~

An index key is also wrong - it makes list state jump when items move. Prefer stable identity *plus* the
mutable values you display.

## State management

Two generations exist. **Do not mix V1 and V2 decorators in one component.**

V1 (simple, shallow observation): `@State` owns local mutable state; `@Prop` one-way down; `@Link` two-way with the parent; `@Provide` / `@Consume` across levels; `@Observed` + `@ObjectLink` to observe one object.

V2 (recommended for new code here - deep observation, better performance):

~~~typescript
@ObservedV2
class BoardState {
  @Trace cells: number[] = new Array<number>(200).fill(0);
  @Trace score: number = 0;
}

@ComponentV2
struct BoardView {
  @Param state: BoardState = new BoardState();            // input
  @Event onLineCleared: (n: number) => void = () => {};    // output
  @Local hoverX: number = 0;                              // private mutable
  @Computed get level(): number { return Math.floor(this.state.score / 1000) + 1; }
}
~~~

The classic bug: `@State board: BoardState` does **not** re-render when `board.cells[i]` changes. Either mark the class `@ObservedV2` with `@Trace` fields (V2), or use `@Observed` with `@ObjectLink` (V1). Reassigning the whole object always works as a fallback.

Where state lives:

- Component-local UI state -> `@State` / `@Local`.
- Cross-page session state (my player id, room code) -> `AppStorage` / `PersistentStorage` via `@StorageLink`.
- Server-authored game state -> one `@ObservedV2` store class owned by the page, mutated only by the network layer.

## Resources

- Strings: `resources/base/element/string.json` -> `$r('app.string.key')`.
- Colors / floats: `color.json` / `float.json` -> `$r('app.color.key')`, `$r('app.float.key')`.
- Raw assets (level JSON, word lists): `resources/rawfile/foo.json` via `getContext(this).resourceManager.getRawFileContent('foo.json')`.
- Media: `resources/base/media/icon.png` -> `$r('app.media.icon')`.
- A missing resource key is a **build error**, which is what you want; a hard-coded user-visible string is a review failure.

## Async, cancellation and concurrency

- `async/await` over `Promise`; never `.then` chains longer than two steps.
- Wrap every awaited platform call in try/catch and narrow with `BusinessError`:

~~~typescript
import { BusinessError } from '@kit.BasicServicesKit';
try {
  await this.socket.connect({ address: { address: host, port: port } });
} catch (e) {
  const err = e as BusinessError;
  hilog.error(0x0000, 'net', 'connect failed %{public}d %{public}s', err.code, err.message);
}
~~~

- The UI thread must never block. Pure computation over ~5 ms or over 10k elements goes to `taskpool` (stateless `@Concurrent` function) rather than `worker`.
- Timers: `setInterval` returns a number; clear it in `aboutToDisappear` or it keeps firing after the page is gone.

## Networking clients (LAN multiplayer)

Declare the permission in `entry/src/main/module.json5`:

~~~json5
"requestPermissions": [
  { "name": "ohos.permission.INTERNET" },
  { "name": "ohos.permission.GET_NETWORK_INFO" }
]
~~~

WebSocket client (`@kit.NetworkKit`):

~~~typescript
import { webSocket } from '@kit.NetworkKit';

const ws = webSocket.createWebSocket();
ws.on('open', () => { ws.send(JSON.stringify(hello)); });
ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
  if (err) { return; }
  handle(typeof data === 'string' ? data : '');
});
ws.on('close', () => { scheduleReconnect(); });
ws.on('error', () => { scheduleReconnect(); });
await ws.connect('ws://' + host + ':' + port + '/game?room=' + room);
~~~

TCP (`socket.constructTCPSocketInstance()`) is the alternative when you want a raw length-prefixed protocol. `socket.constructTCPSocketServerInstance()` and `webSocket.createWebSocketServer()` let a device *host* a room with no external server.

Non-obvious facts that cost hours:

- **The HarmonyOS emulator is NAT'd.** It cannot reach a server on your Mac by LAN IP; use `10.0.2.2`, or forward with `hdc fport tcp:<hostPort> tcp:<devicePort>`. Real devices need the Mac's LAN IP and the same Wi-Fi.
- Cleartext `http://` and `ws://` work for LAN debugging; if a security policy blocks it, extend the network security config rather than switching to TLS.
- A message callback may deliver `ArrayBuffer` even for text frames - always narrow the type.
- Reconnect with exponential backoff plus jitter (250 ms -> 5 s cap). Reconnect storms from 30 students is the classic classroom failure.

## The build/run loop

This project has no local `hvigorw`; use the DevEco-bundled one. **Both** environment variables are mandatory:

~~~bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
HV=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
"$HV" assembleHap --mode module -p product=default --no-daemon

HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
"$HDC" list targets                    # 127.0.0.1:5555 = running emulator
"$HDC" install -r entry/build/default/outputs/default/entry-default-unsigned.hap
"$HDC" shell aa start -a EntryAbility -b com.example.gameexample20261016
"$HDC" shell hilog | grep -i testTag   # runtime logs
"$HDC" shell snapshot_display -f /data/local/tmp/s.jpeg   # then hdc file recv
~~~

**Install the signed HAP.** Once the project has a signing config, `assembleHap` emits both
`entry-default-signed.hap` and `entry-default-unsigned.hap`. Installing the unsigned one over a device that
already has the signed one prints `AppMod finish` (looks like success) but the system does not replace the app —
your code changes silently never run. When "I changed the code, the build passed, the install said OK, and nothing
changed", check which artifact you installed first. Installing a differently-signed package also wipes app data.

Without `DEVECO_SDK_HOME` the build fails immediately with `00303217 Configuration Error`. Without `JAVA_HOME` the ArkTS compile still succeeds and then `PackageHap` fails with `00308018 Unknown Error`, hiding "Unable to locate a Java Runtime" — this machine has no system JDK, only DevEco's bundled JBR 25. Because hvigor may carry `PackageHap` over as UP-TO-DATE from an earlier DevEco Studio build, this failure only surfaces after you change source. Unsigned HAPs install fine on this emulator; the `SignHap` warning is expected while `signingConfigs` stays empty.

## Review checklist

- [ ] No `any` / `unknown`; all wire data has a declared `interface`.
- [ ] `build()` has one root and no side effects.
- [ ] Every subscription / timer / socket is released in `aboutToDisappear`.
- [ ] `ForEach` keys are stable, unique, and include every mutable field the row shows.
- [ ] No V1/V2 decorator mixing; nested objects are observed explicitly.
- [ ] `INTERNET` permission declared before any network call.
- [ ] `hilog` used (not `console.log`) with a domain and `%{public}s` formatting.
