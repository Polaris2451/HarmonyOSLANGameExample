import { Toast } from '../utils/Toast';
import { Confirm } from '../utils/Confirm';
import { AppButton } from '../components/AppButton';
import { RoomSession } from '../app/RoomSession';
import { EventKind, GomokuState } from '../core/games/gomoku/GomokuGame';
import { GOMOKU_SIZE, STONE_BLACK, STONE_EMPTY, STONE_WHITE } from '../core/games/gomoku/GomokuRules';
import { BoardPalette } from '../core/games/gomoku/GomokuPalette';

/**
 * 五子棋对局页。
 * 棋盘用 Canvas 绘制；点击换算成棋盘坐标后只发送「落子意图」，
 * 是否合法、是否获胜一律由房主判定后广播回来。
 */
@Component
export struct GomokuPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State cells: number[] = [];
  @State turn: number = STONE_BLACK;
  @State winner: number = STONE_EMPTY;
  @State finished: boolean = false;
  @State lastX: number = -1;
  @State lastY: number = -1;
  /** 本地预落的那颗子：服务器回包前先画出来，落子才跟手。收到权威棋盘后被覆盖。 */
  @State pendingX: number = -1;
  @State pendingY: number = -1;
  @State blackName: string = '';
  @State whiteName: string = '';
  @State myColor: number = STONE_EMPTY;
  @State boardSize: number = 300;
  @State turnLabel: ResourceStr = $r('app.string.game_black_turn');
  @State hasHint: boolean = false;
  @State hintText: ResourceStr = '';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private cell: number = 0;
  private pad: number = 0;
  private canvasReady: boolean = false;

  aboutToAppear(): void {
    const session: RoomSession = RoomSession.get();
    session.onState = (payload: string) => {
      this.applyState(payload);
    };
    session.onEvent = (kind: string, message: string) => {
      this.onEvent(kind, message);
    };
    // 对局页可能在 STATE 之后才创建，先把会话里的快照补上
    if (session.gamePayload.length > 0) {
      this.applyState(session.gamePayload);
    }
  }

  private applyState(payload: string): void {
    let state: GomokuState;
    try {
      state = JSON.parse(payload) as GomokuState;
    } catch (err) {
      return;
    }
    this.cells = state.cells;
    this.turn = state.turn;
    this.winner = state.winner;
    this.finished = state.finished;
    this.lastX = state.lastX;
    this.lastY = state.lastY;
    this.blackName = state.blackName;
    this.whiteName = state.whiteName;

    const selfId: string = RoomSession.get().selfId;
    if (selfId.length > 0 && selfId === state.blackId) {
      this.myColor = STONE_BLACK;
    } else if (selfId.length > 0 && selfId === state.whiteId) {
      this.myColor = STONE_WHITE;
    } else {
      this.myColor = STONE_EMPTY;
    }
    // 权威棋盘到了，本地预落的子作废（服务端要么已经收录，要么已经拒绝）
    this.pendingX = -1;
    this.pendingY = -1;
    this.refreshLabels();
    this.draw();
  }

  private refreshLabels(): void {
    if (this.turn === STONE_BLACK) {
      this.turnLabel = $r('app.string.game_black_turn');
    } else {
      this.turnLabel = $r('app.string.game_white_turn');
    }
  }

  private onEvent(kind: string, message: string): void {
    if (kind !== EventKind.ILLEGAL) {
      return;
    }
    // 被拒绝时不一定会再收到 STATE，这里必须自己把预落的子撤掉
    this.pendingX = -1;
    this.pendingY = -1;
    this.draw();
    this.hintText = this.illegalText(message);
    this.hasHint = true;
    Toast.show(this.getUIContext(), this.hintText);
  }

  private illegalText(reason: string): Resource {
    if (reason === 'occupied') {
      return $r('app.string.game_illegal_occupied');
    }
    if (reason === 'not_your_turn') {
      return $r('app.string.game_illegal_turn');
    }
    if (reason === 'finished') {
      return $r('app.string.game_illegal_finished');
    }
    return $r('app.string.game_illegal_other');
  }

  private statusText(): Resource {
    if (this.finished) {
      if (this.winner === STONE_EMPTY) {
        return $r('app.string.game_draw');
      }
      if (this.myColor === STONE_EMPTY) {
        return this.winner === STONE_BLACK
          ? $r('app.string.game_black_win') : $r('app.string.game_white_win');
      }
      return this.myColor === this.winner
        ? $r('app.string.game_win') : $r('app.string.game_lose');
    }
    if (this.myColor === STONE_EMPTY) {
      return $r('app.string.game_spectating');
    }
    return this.turn === this.myColor
      ? $r('app.string.game_your_turn') : $r('app.string.game_wait_turn');
  }

  private isMyTurn(): boolean {
    return !this.finished && this.myColor !== STONE_EMPTY && this.turn === this.myColor;
  }

  private draw(): void {
    if (!this.canvasReady || this.cell <= 0) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    const size: number = this.boardSize;
    ctx.clearRect(0, 0, size, size);
    ctx.fillStyle = BoardPalette.boardBg;
    ctx.fillRect(0, 0, size, size);

    const pad: number = this.pad;
    const cell: number = this.cell;
    const last: number = pad + (GOMOKU_SIZE - 1) * cell;

    ctx.strokeStyle = BoardPalette.line;
    ctx.lineWidth = 1;
    for (let i = 0; i < GOMOKU_SIZE; i++) {
      const p: number = pad + i * cell;
      ctx.beginPath();
      ctx.moveTo(pad, p);
      ctx.lineTo(last, p);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(p, pad);
      ctx.lineTo(p, last);
      ctx.stroke();
    }

    const stars: number[] = [3, 7, 11];
    ctx.fillStyle = BoardPalette.star;
    for (const sy of stars) {
      for (const sx of stars) {
        ctx.beginPath();
        ctx.arc(pad + sx * cell, pad + sy * cell, Math.max(2, cell * 0.1), 0, Math.PI * 2);
        ctx.fill();
      }
    }

    const radius: number = cell * 0.42;
    for (let y = 0; y < GOMOKU_SIZE; y++) {
      for (let x = 0; x < GOMOKU_SIZE; x++) {
        const value: number = this.cells[y * GOMOKU_SIZE + x];
        if (value === STONE_EMPTY) {
          continue;
        }
        ctx.beginPath();
        ctx.arc(pad + x * cell, pad + y * cell, radius, 0, Math.PI * 2);
        ctx.fillStyle = value === STONE_BLACK ? BoardPalette.black : BoardPalette.white;
        ctx.fill();
        if (value === STONE_WHITE) {
          ctx.strokeStyle = BoardPalette.edge;
          ctx.lineWidth = 1;
          ctx.stroke();
        }
      }
    }

    // 本地预落的那一颗：先当权威棋子画出来，手感才跟手
    if (this.pendingX >= 0 && this.pendingY >= 0 && this.myColor !== STONE_EMPTY) {
      ctx.beginPath();
      ctx.arc(pad + this.pendingX * cell, pad + this.pendingY * cell, radius, 0, Math.PI * 2);
      ctx.fillStyle = this.myColor === STONE_BLACK ? BoardPalette.black : BoardPalette.white;
      ctx.fill();
      if (this.myColor === STONE_WHITE) {
        ctx.strokeStyle = BoardPalette.edge;
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }

    // 最后一手的标记跟着预落的那一颗走，这样本地和服务端的视觉完全一致
    const markX: number = this.pendingX >= 0 ? this.pendingX : this.lastX;
    const markY: number = this.pendingX >= 0 ? this.pendingY : this.lastY;
    if (markX >= 0 && markY >= 0) {
      ctx.beginPath();
      ctx.arc(pad + markX * cell, pad + markY * cell,
        Math.max(3, cell * 0.16), 0, Math.PI * 2);
      ctx.strokeStyle = BoardPalette.last;
      ctx.lineWidth = 2;
      ctx.stroke();
    }
  }

  private handleTap(px: number, py: number): void {
    if (!this.isMyTurn() || this.cell <= 0) {
      return;
    }
    // 上一手还没被服务端确认前不再接受落子，否则本地连点会变成两次落子
    if (this.pendingX >= 0) {
      return;
    }
    const x: number = Math.round((px - this.pad) / this.cell);
    const y: number = Math.round((py - this.pad) / this.cell);
    if (x < 0 || x >= GOMOKU_SIZE || y < 0 || y >= GOMOKU_SIZE) {
      return;
    }
    if (this.cells[y * GOMOKU_SIZE + x] !== STONE_EMPTY) {
      return;
    }
    this.hasHint = false;
    // 先本地落一颗，不等服务器回包
    this.pendingX = x;
    this.pendingY = y;
    this.draw();
    RoomSession.get().sendInput('place', x, y);
  }

  private async leaveRoom(): Promise<void> {
    const ok: boolean = await Confirm.ask(this.getUIContext(),
      $r('app.string.leave_title'), $r('app.string.leave_msg'), $r('app.string.leave_ok'));
    if (!ok) {
      return;
    }
    await RoomSession.get().leave();
    this.pathStack.pop();
  }

  @Builder
  PlayerLine(color: number, name: string) {
    Row({ space: 8 }) {
      Text('●')
        .fontSize(14)
        .fontColor(color === STONE_BLACK ? $r('app.color.stone_black') : $r('app.color.stone_white'))
      Text(color === STONE_BLACK ? $r('app.string.game_black') : $r('app.string.game_white'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
      Text(name)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.myColor === color) {
        Text($r('app.string.game_you_suffix'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (!this.finished && this.turn === color) {
        Text('▶')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.brand'))
      }
    }
    .width('100%')
    .height(34)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 12 }) {
          Column() {
            Canvas(this.ctx)
              .width(this.boardSize)
              .height(this.boardSize)
              .onReady(() => {
                this.canvasReady = true;
                this.draw();
              })
              .onClick((event: ClickEvent) => {
                this.handleTap(event.x, event.y);
              })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onAreaChange((oldArea: Area, newArea: Area) => {
            const w: number = Number(newArea.width);
            const h: number = Number(newArea.height);
            const size: number = Math.min(w, h) - 6;
            if (size > 0 && Math.abs(size - this.boardSize) > 1) {
              this.boardSize = size;
              this.cell = size / GOMOKU_SIZE;
              this.pad = this.cell / 2;
              this.draw();
            }
          })

          Column({ space: 8 }) {
            Text($r('app.string.game_gomoku'))
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            if (!this.finished) {
              Text(this.turnLabel)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }

            this.PlayerLine(STONE_BLACK, this.blackName)
            this.PlayerLine(STONE_WHITE, this.whiteName)

            Divider().color($r('app.color.border_subtle'))

            Text(this.statusText())
              .fontSize($r('app.float.font_subtitle'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.finished ? $r('app.color.brand') : $r('app.color.text_primary'))
              .width('100%')

            if (this.hasHint) {
              Text(this.hintText)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.danger'))
                .width('100%')
            }

            Blank()

            if (this.finished) {
              AppButton({
                label: $r('app.string.game_back_room'),
                primary: true,
                active: true,
                onTap: () => {
                  this.pathStack.pop();
                }
              })
            } else {
              AppButton({
                label: $r('app.string.game_resign'),
                primary: false,
                active: this.myColor !== STONE_EMPTY,
                onTap: () => {
                  RoomSession.get().sendInput('resign', -1, -1);
                }
              })
            }

            AppButton({
              label: $r('app.string.room_leave'),
              primary: false,
              active: true,
              onTap: () => {
                this.leaveRoom();
              }
            })
          }
          .width($r('app.float.sidebar_width_narrow'))
          .height('100%')
          .padding($r('app.float.card_padding'))
          .alignItems(HorizontalAlign.Start)
          .backgroundColor($r('app.color.bg_surface'))
          .borderRadius($r('app.float.radius_card'))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
    }
    .hideTitleBar(true)
  }
}
