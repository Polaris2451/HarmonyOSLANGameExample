---
name: lan-multiplayer-game
description: Use when designing or implementing a LAN multiplayer game for this course project - authoritative server vs host vs P2P, tick and sync model, message protocol and versioning, room and reconnect handling, Canvas rendering, plus concrete rules for Tetris battle and Draw and Guess. Targets Android-free HarmonyOS 6.0.0 / API 26 clients with a classroom server.
whenToUse: Adding or debugging real-time multiplayer, a game loop, network sync, rooms, or a new mini-game on the LAN.
---

# LAN multiplayer games (HarmonyOS clients + classroom server)

The scenario: **one server, many students**. Students run an emulator or a real device on the same Wi-Fi/LAN and connect with an IP and port. Nothing may require port forwarding, a public IP, or a per-student tunnel.

## Pick the topology first

| Topology | When | Cost |
|---|---|---|
| **Authoritative server** (recommended) | 2+ players, scores must be trustworthy, reconnection matters | one machine runs the server; all clients are thin |
| **Host-authoritative** (in-app server) | no laptop available, 2 players | the host device uses `socket.constructTCPSocketServerInstance()` or `webSocket.createWebSocketServer()`; host advantage and NAT pain |
| **P2P / relay** | demo only | NAT traversal, desync, no single truth - avoid for graded work |

Choose the authoritative server unless a stated constraint forces otherwise. It makes every later problem (reconnect, spectators, cheating, replays) tractable.

The server itself must be **dependency-free and boring**: a single Node.js file using the built-in `http` + `net` modules (or `ws` if the class already has it). Students install nothing but Node.

## The tick model

Render and simulate are different loops.

- **Server**: fixed tick, 10-20 Hz. All rules (gravity, line clears, guessing, scoring) run here. `setInterval(tick, 50)` plus a monotonic clock; never trust a client timestamp.
- **Client**: render at display rate; interpolate between the last two server snapshots for positions; send *input*, never *state*.
- **Never** let the client decide a score, a line clear, or a correct guess.

~~~typescript
// server skeleton
interface Player { id: string; ws: Conn; room: string; alive: boolean; lastSeq: number; }
const rooms = new Map<string, Room>();

function tick(): void {
  const now = Date.now();
  for (const room of rooms.values()) {
    room.step(now);                              // pure simulation
    const frame = room.snapshot();               // full or delta
    for (const p of room.players) { p.ws.send(encode(frame)); }
  }
}
setInterval(tick, 50);
~~~

## Protocol

One envelope, one version, one codec. Length-prefixed newline-delimited JSON is the most debuggable choice on a LAN.

~~~typescript
export interface Envelope {
  v: number;      // protocol version - reject mismatches loudly in class
  t: string;      // 'hello' | 'join' | 'input' | 'state' | 'event' | 'ping'
  seq: number;    // sender-monotonic; detect drops/dups
  room?: string;
  ts: number;     // server time on server->client frames
  body: string;   // JSON string of a typed payload
}
~~~

Rules that prevent 90% of classroom bugs:

1. **Handshake first**: client sends `hello` with `{name, protocolVersion}`; server replies `welcome` with `{playerId, roomCode, tickRate, seed}`. Reject a version mismatch with a human-readable reason.
2. **Never send unbounded state.** A delta is `{id, changed fields}`; a full snapshot is only for join and reconnect.
3. **Sequence numbers are per-connection and checked.** Out-of-order input is dropped, not applied.
4. **Heartbeat both ways** (ping every 3 s, drop after 10 s silent) so a closed laptop lid frees the slot.
5. **Every message is at most a few KB.** A drawing stroke batch is the one exception; cap it (e.g. 200 points) and split.
6. **Idempotent reconnect**: the client sends `resume{playerId, token}`; the server reattaches it to the same seat with the current snapshot.

## In-app hosting on HarmonyOS (verified)

`webSocket.createWebSocketServer().start(config)` is picky on emulators:

- An explicit `serverIP` fails with `2302999 Websocket Unknown Other Error`.
- **Both connection caps must stay <= 10** (the documented defaults): `maxConcurrentClientsNumber: 16` fails the
  same way. `8 / 8` is known good.
- `maxConnectionsForOneClient` counts **per source IP**, not per room. Behind emulator port forwarding every
  client — including the host's own loopback client — arrives as `127.0.0.1`, so a small value silently rejects
  later players at the WebSocket layer (`server error: 200`) before your own room-full logic ever runs. Keep it
  at least as large as the expected number of simultaneous players.

Port problems surface as `2302005`/`2302007`, NIC problems as `2302004`, permission as `201`.

Two emulators cannot reach each other directly. Bridge them through the host machine:
`hdc -t <hostDevice> fport tcp:8080 tcp:8080` maps the host's loopback to the hosting device, and the joining
emulator connects to `10.0.2.2:8080`. `hdc fport` binds loopback only, so a real device cannot reach an emulator
host through the computer's LAN IP. The mapping is also lost whenever an emulator reconnects — re-check `hdc fport ls`
before every class.

When rejecting a connection (room full, version mismatch), **await the send AND delay the close by a few hundred
milliseconds**: even after `send()`'s promise settles the frame may still be in the socket buffer, so an immediate
`close()` truncates it and the client only sees a bare disconnect. A `setTimeout` of ~500 ms before `close()` is
enough for the client to read the reason.

## Transport on HarmonyOS

- `webSocket` from `@kit.NetworkKit` is the right default: framing, text frames, and an `on('close')` you can drive reconnect from.
- `socket.constructTCPSocketInstance()` when you want to teach framing yourself - wrap the callback API in a Promise and buffer bytes into lines.
- `ohos.permission.INTERNET` is required; add `ohos.permission.GET_NETWORK_INFO` if you display the local IP.
- Get the server IP for the classroom: have the server print it at startup, or let the client scan a small port range on the `/24` it is already on. Never hard-code one student's IP.

**Emulator vs real device**

- Emulator -> host machine: `10.0.2.2` maps to the Mac's loopback, or use `hdc fport tcp:8080 tcp:8080` and connect to `127.0.0.1:8080`.
- Real device -> Mac: use the Mac's LAN address (`ipconfig getifaddr en0`) and make sure macOS's firewall allows the Node process. Both must be on the same Wi-Fi with client isolation off.

## Rendering the game surface

- One `Canvas` per game board, redrawn from state - not one ArkUI component per cell. A 10x20 board via `Grid`/`ForEach` re-renders dozens of nodes per tick; a canvas draws 200 rects.
- Size the board from the measured container (`onAreaChange`), keep a `cell` variable, and derive every rectangle from it.
- Drawing games: store strokes in **normalized** coordinates (0..1 of the canvas box) so phone, tablet and landscape all reproduce the same picture.
- `setWindowKeepScreenOn(true)` when a round starts, release it when the match ends.

~~~typescript
private draw(ctx: CanvasRenderingContext2D): void {
  ctx.clearRect(0, 0, this.w, this.h);
  for (let y = 0; y < 20; y++) {
    for (let x = 0; x < 10; x++) {
      const v = this.cells[y * 10 + x];
      if (!v) { continue; }
      ctx.fillStyle = COLORS[v];
      ctx.fillRect(x * this.cell, y * this.cell, this.cell - 1, this.cell - 1);
    }
  }
}
~~~

## Game 1 - Tetris battle (2-4 players)

Server-authoritative, per-player board, line clears send garbage to opponents.

- **7-bag randomizer**: shuffle `[I,J,L,O,S,T,Z]`, deal, reshuffle. Never `Math.random()` per piece - it produces droughts students will call cheating.
- **Determinism**: the server holds the bag; the client receives the current piece and next queue. The client sends `input{action:'left'|'right'|'rotateCW'|'softDrop'|'hardDrop'}` only.
- **Input cadence**: the server coalesces repeats (DAS/ARR) so a held key cannot fire 200 moves/s. Cap at ~10 inputs/s per player.
- **Rules**: lock delay ~500 ms with a 15-move reset cap; line-clear scoring `[0,100,300,500,800] * level`; garbage `[0,0,1,2,4]` lines, cancelled against incoming garbage first.
- **Elimination**: top-out -> player becomes spectator; last standing wins. The server must keep simulating eliminated players' boards only until they top out.
- **Spectator/reconnect**: a full snapshot of every board is ~1 KB; resend on join.

## Game 2 - Draw and Guess (3-8 players)

A turn-based state machine, so model it explicitly and let the server own the timer.

~~~typescript
type Phase = 'lobby' | 'choosing' | 'drawing' | 'reveal' | 'scoreboard' | 'ended';
~~~

- **Round flow**: server picks the drawer -> drawer chooses 1 of 3 words (15 s) -> drawing phase (60-90 s) -> reveal -> next drawer. Rotate so everyone draws once per round.
- **Drawing sync**: the drawer streams stroke *batches*, not points: `stroke{color,width,points:[[x,y],...]}` with normalized coords; `clear` and `undo` are explicit messages. Late joiners get the accumulated stroke list.
- **Guess validation** happens only on the server: normalize (trim, lower-case, collapse spaces), reject the guess if it is a substring of the answer for a player who already guessed, and mask the answer in all outbound messages.
- **Scoring**: guesser `base - elapsed/10`; drawer gets `(guessed count) * 50`. Close guesses ("hot/cold") are a nice touch but reveal too much if tuned wrong.
- **Anti-cheat for a classroom**: the answer is only ever in the drawer's message; everyone else sees `"__"` with the length. This is the single most commonly botched detail.
- **Word list** lives in `resources/rawfile/words.json` for the single-player/local mode and on the server for online play.

## Testing a multiplayer game without 30 phones

1. A **headless bot client** in Node that joins, plays randomly, and asserts it never desyncs. Run 20 of them in one process.
2. A **protocol log**: every frame is JSON; dump to `logs/room-<id>.jsonl` and replay it against the server to reproduce a bug.
3. **Two clients on one machine**: one emulator plus one `node` CLI client is enough to prove the loop.
4. Assert invariants server-side and log: piece count, board cell count, score monotonicity, phase transitions.

## Review checklist

- [ ] All rules execute on the server; clients send input, not state.
- [ ] `hello`/`welcome` handshake with protocol version and a readable rejection.
- [ ] Heartbeat plus exponential-backoff reconnect with jitter.
- [ ] Per-player sequence numbers; duplicates and late frames dropped.
- [ ] Board drawn on a canvas sized from the measured container.
- [ ] `INTERNET` permission declared; emulator tested via `10.0.2.2` or `hdc fport`.
- [ ] Server prints its LAN address on startup.
- [ ] 20-bot soak test survives 10 minutes with zero desync.
