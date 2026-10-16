import { AppButton } from '../components/AppButton';
import { RoomSession } from '../app/RoomSession';
import { Confirm } from '../utils/Confirm';
import { TetrisPlayerView, TetrisState } from '../core/games/tetris/TetrisGame';
import { COLS, ROWS } from '../core/games/tetris/TetrisBoard';
import { colorIndex, rotationsOf } from '../core/games/tetris/TetrisPieces';

/** Canvas 里不能用 $r，颜色只能写成字符串。0 空，1..7 方块，8 垃圾行。 */
const COLORS: string[] = [
  '#FFFFFF', '#22B8CF', '#F5B301', '#7C5CFC', '#2FA37A', '#E5484D', '#3B6FF5', '#F2820A', '#8A94A6'
];
const GRID_COLOR: string = '#EDEFF2';
const BORDER_COLOR: string = '#D7DBE0';
const NEXT_CELL: number = 14;

/**
 * 双人俄罗斯方块对战页。
 *
 * 左边是自己的棋盘（会额外画出正在下落的方块），右边是对手棋盘快照。
 * 所有判定都在房主那一侧，这里只负责画和发操作意图。
 */
@Component
export struct TetrisPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State myBoard: string = '';
  @State foeBoard: string = '';
  @State myName: string = '';
  @State foeName: string = '';
  @State myScore: number = 0;
  @State foeScore: number = 0;
  @State myLines: number = 0;
  @State myLevel: number = 1;
  @State incoming: number = 0;
  @State kind: string = '';
  @State rot: number = 0;
  @State px: number = 0;
  @State py: number = 0;
  @State nextKind: string = '';
  @State selfOut: boolean = false;
  @State foeActive: boolean = true;
  @State finished: boolean = false;
  @State message: string = '';
  @State winnerName: string = '';

  private myCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private foeCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private nextCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private myReady: boolean = false;
  private foeReady: boolean = false;
  private myW: number = 0;
  private myH: number = 0;
  private foeW: number = 0;
  private foeH: number = 0;

  aboutToAppear(): void {
    const session: RoomSession = RoomSession.get();
    session.onState = (payload: string) => {
      this.applyState(payload);
    };
    if (session.gamePayload.length > 0) {
      this.applyState(session.gamePayload);
    }
  }

  private applyState(payload: string): void {
    let state: TetrisState;
    try {
      state = JSON.parse(payload) as TetrisState;
    } catch (err) {
      return;
    }
    this.kind = state.kind;
    this.rot = state.rot;
    this.px = state.x;
    this.py = state.y;
    this.nextKind = state.nextKind;
    this.selfOut = state.selfOut;
    this.finished = state.finished;
    this.message = state.message;
    this.winnerName = state.winnerName;

    const players: TetrisPlayerView[] = state.players;
    for (const p of players) {
      if (p.isSelf) {
        this.myBoard = p.board;
        this.myName = p.nickname;
        this.myScore = p.score;
        this.myLines = p.lines;
        this.myLevel = p.level;
        this.incoming = p.incoming;
      } else {
        this.foeBoard = p.board;
        this.foeName = p.nickname;
        this.foeScore = p.score;
        this.foeActive = p.active;
      }
    }
    this.repaint();
  }

  // ---------- 绘制 ----------

  private fillCell(ctx: CanvasRenderingContext2D, x: number, y: number,
    cell: number, ox: number, oy: number, color: string): void {
    ctx.fillStyle = color;
    ctx.fillRect(ox + x * cell + 1, oy + y * cell + 1, cell - 2, cell - 2);
  }

  private paintBoard(ctx: CanvasRenderingContext2D, board: string, cell: number,
    ox: number, oy: number, drawActive: boolean): void {
    const wpx: number = COLS * cell;
    const hpx: number = ROWS * cell;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(ox, oy, wpx, hpx);

    ctx.strokeStyle = GRID_COLOR;
    ctx.lineWidth = 1;
    for (let x = 0; x <= COLS; x++) {
      ctx.beginPath();
      ctx.moveTo(ox + x * cell, oy);
      ctx.lineTo(ox + x * cell, oy + hpx);
      ctx.stroke();
    }
    for (let y = 0; y <= ROWS; y++) {
      ctx.beginPath();
      ctx.moveTo(ox, oy + y * cell);
      ctx.lineTo(ox + wpx, oy + y * cell);
      ctx.stroke();
    }

    for (let y = 0; y < ROWS; y++) {
      for (let x = 0; x < COLS; x++) {
        const idx: number = y * COLS + x;
        if (idx >= board.length) {
          continue;
        }
        const v: number = board.charCodeAt(idx) - 48;
        if (v > 0) {
          this.fillCell(ctx, x, y, cell, ox, oy, COLORS[v]);
        }
      }
    }

    if (drawActive && this.kind.length > 0) {
      const states: number[][][] = rotationsOf(this.kind);
      const cells: number[][] = states[this.rot % 4];
      const color: string = COLORS[colorIndex(this.kind)];
      for (const c of cells) {
        const gy: number = this.py + c[1];
        if (gy >= 0) {
          this.fillCell(ctx, this.px + c[0], gy, cell, ox, oy, color);
        }
      }
    }

    ctx.strokeStyle = BORDER_COLOR;
    ctx.lineWidth = 2;
    ctx.strokeRect(ox, oy, wpx, hpx);
  }

  private cellFor(w: number, h: number): number {
    const c: number = Math.floor(Math.min(w / COLS, h / ROWS));
    return c > 0 ? c : 1;
  }

  private repaint(): void {
    if (this.myReady && this.myW > 0) {
      const cell: number = this.cellFor(this.myW, this.myH);
      this.paintBoard(this.myCtx, this.myBoard, cell,
        (this.myW - cell * COLS) / 2, (this.myH - cell * ROWS) / 2,
        !this.selfOut && !this.finished);
    }
    if (this.foeReady && this.foeW > 0) {
      const cell: number = this.cellFor(this.foeW, this.foeH);
      this.paintBoard(this.foeCtx, this.foeBoard, cell,
        (this.foeW - cell * COLS) / 2, (this.foeH - cell * ROWS) / 2, false);
    }
    this.paintNext();
  }

  /** 用 4×4 的格子画下一个方块，居中。 */
  private paintNext(): void {
    const ctx: CanvasRenderingContext2D = this.nextCtx;
    const size: number = NEXT_CELL * 4;
    ctx.clearRect(0, 0, size, size);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, size, size);
    if (this.nextKind.length === 0) {
      return;
    }
    const states: number[][][] = rotationsOf(this.nextKind);
    const cells: number[][] = states[0];
    const color: string = COLORS[colorIndex(this.nextKind)];
    // 形状矩阵可能贴着边（比如 S 占右半边），按包围盒居中到 4×4 格子里
    let minX: number = 4;
    let maxX: number = -1;
    let minY: number = 4;
    let maxY: number = -1;
    for (const c of cells) {
      if (c[0] < minX) {
        minX = c[0];
      }
      if (c[0] > maxX) {
        maxX = c[0];
      }
      if (c[1] < minY) {
        minY = c[1];
      }
      if (c[1] > maxY) {
        maxY = c[1];
      }
    }
    const ox: number = Math.floor((4 - (maxX - minX + 1)) / 2) - minX;
    const oy: number = Math.floor((4 - (maxY - minY + 1)) / 2) - minY;
    for (const c of cells) {
      this.fillCell(ctx, c[0] + ox, c[1] + oy, NEXT_CELL, 0, 0, color);
    }
  }

  // ---------- 操作 ----------

  /** 只发意图，落点判定在房主那一侧。 */
  private send(action: string, dir: number): void {
    if (this.finished || this.selfOut) {
      return;
    }
    RoomSession.get().sendInputText(action, dir, 0, '');
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
  CtrlBtn(label: string, enabled: boolean, tap: () => void) {
    Text(label)
      .fontSize($r('app.float.font_body'))
      .fontColor(enabled ? $r('app.color.text_primary') : $r('app.color.text_disabled'))
      .textAlign(TextAlign.Center)
      .height(40)
      .layoutWeight(1)
      .backgroundColor($r('app.color.bg_sunken'))
      .borderRadius($r('app.float.radius_chip'))
      .onClick(() => {
        tap();
      })
  }

  @Builder
  BoardPane(title: ResourceStr, name: string, score: number, mine: boolean) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(title)
          .fontSize($r('app.float.font_caption'))
          .fontWeight(mine ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(mine ? $r('app.color.accent_tetris') : $r('app.color.text_secondary'))
        Text(name)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(score.toString())
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.accent_tetris'))
      }
      .width('100%')

      if (mine) {
        Canvas(this.myCtx)
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_surface'))
          .borderRadius($r('app.float.radius_input'))
          .onReady(() => {
            this.myReady = true;
            this.repaint();
          })
          .onAreaChange((oldArea: Area, newArea: Area) => {
            this.myW = Number(newArea.width);
            this.myH = Number(newArea.height);
            this.repaint();
          })
      } else {
        Canvas(this.foeCtx)
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.bg_surface'))
          .borderRadius($r('app.float.radius_input'))
          .onReady(() => {
            this.foeReady = true;
            this.repaint();
          })
          .onAreaChange((oldArea: Area, newArea: Area) => {
            this.foeW = Number(newArea.width);
            this.foeH = Number(newArea.height);
            this.repaint();
          })
      }
    }
    .layoutWeight(1)
    .height('100%')
    .padding(8)
    .alignItems(HorizontalAlign.Start)
    // 自己的棋盘加底色和描边，一眼能分出左右
    .backgroundColor(mine ? $r('app.color.accent_tetris_soft') : $r('app.color.bg_surface'))
    .borderRadius($r('app.float.radius_panel'))
    .border({
      width: mine ? 2 : 1,
      color: mine ? $r('app.color.accent_tetris') : $r('app.color.border_subtle')
    })
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 12 }) {
          // 对手在左
          Column({ space: 6 }) {
            this.BoardPane($r('app.string.tetris_foe'), this.foeName, this.foeScore, false)
            if (!this.foeActive) {
              Text($r('app.string.tetris_out'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_disabled'))
            }
          }
          .layoutWeight(1)
          .height('100%')

          // 我在右，高亮
          this.BoardPane($r('app.string.tetris_self'), this.myName, this.myScore, true)

          // 侧栏：预览、统计、操作
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Text($r('app.string.tetris_next'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              Canvas(this.nextCtx)
                .width(NEXT_CELL * 4)
                .height(NEXT_CELL * 4)
                .backgroundColor($r('app.color.bg_sunken'))
                .borderRadius($r('app.float.radius_input'))
                .onReady(() => {
                  this.paintNext();
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Row() {
              Text($r('app.string.tetris_lines'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              Text(this.myLines.toString())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text($r('app.string.tetris_level'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              Text(this.myLevel.toString())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')

            if (this.incoming > 0) {
              Row() {
                Text($r('app.string.tetris_incoming'))
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.warning'))
                Text(this.incoming.toString())
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.warning'))
              }
              .width('100%')
            }

            if (this.finished) {
              Text(this.message === 'win' ? $r('app.string.tetris_you_win')
                : $r('app.string.tetris_you_lose'))
                .fontSize($r('app.float.font_subtitle'))
                .fontWeight(FontWeight.Medium)
                .fontColor(this.message === 'win' ? $r('app.color.success') : $r('app.color.danger'))
                .width('100%')
            } else if (this.selfOut) {
              Text($r('app.string.tetris_out'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.danger'))
                .width('100%')
            }

            Blank()

            Row({ space: 8 }) {
              this.CtrlBtn('←', !this.finished, () => {
                this.send('move', -1);
              })
              this.CtrlBtn('→', !this.finished, () => {
                this.send('move', 1);
              })
            }
            .width('100%')

            // CtrlBtn 用 layoutWeight(1) 撑满宽度，直接放在 Column 里会被当成纵向拉伸，
            // 所以必须放在 Row 里
            Row({ space: 8 }) {
              this.CtrlBtn('↻', !this.finished && !this.selfOut, () => {
                this.send('rotate', 1);
              })
              this.CtrlBtn('↓', !this.finished && !this.selfOut, () => {
                this.send('harddrop', 1);
              })
            }
            .width('100%')

            if (this.finished) {
              AppButton({
                label: $r('app.string.game_back_room'),
                primary: true,
                active: true,
                onTap: () => {
                  this.pathStack.pop();
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
          .width(230)
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
