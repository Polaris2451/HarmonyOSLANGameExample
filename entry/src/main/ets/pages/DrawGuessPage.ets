import { Toast } from '../utils/Toast';
import { Confirm } from '../utils/Confirm';
import { AppButton } from '../components/AppButton';
import { RoomSession } from '../app/RoomSession';
import { DrawEvent, DrawPhase, DrawPlayerView, DrawState } from '../core/games/drawguess/DrawGuessGame';

/** 一条笔画批次，坐标是 0..1 的归一化值。 */
class DrawSeg {
  w: number = 4;
  c: string = '#22252B';
  p: number[][] = [];
  /** true 表示这是新一笔的起点。 */
  n: boolean = true;
}

const PALETTE: string[] = ['#22252B', '#E5484D', '#2FA37A', '#3B6FF5'];
const BRUSH_WIDTH: number = 5;
const FLUSH_POINTS: number = 6;

/**
 * 画布固定 4:3。
 * 关键点是「逻辑比例固定、物理尺寸自适应」：每台设备都取可用区域里最大的 4:3 内接矩形，
 * 这样手机、平板、折叠屏都能铺满各自的空间，而两端看到的画布形状始终一致 ——
 * 否则按宽度、高度分别归一化后，笔迹在不同比例的屏幕上会被拉伸变形。
 */
const CANVAS_ASPECT: number = 4 / 3;

/**
 * 你画我猜对局页。
 * 画布用归一化坐标，所以手机、平板、横竖屏都能还原同一张画。
 * 猜词只在房主那边判定，客户端拿不到答案。
 */
@Component
export struct DrawGuessPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State phase: string = DrawPhase.CHOOSING;
  @State round: number = 1;
  @State totalRounds: number = 3;
  @State drawerId: string = '';
  @State drawerName: string = '';
  @State word: string = '';
  @State wordMask: string = '';
  @State wordLength: number = 0;
  @State candidates: string[] = [];
  @State players: DrawPlayerView[] = [];
  @State secondsLeft: number = 0;
  @State finished: boolean = false;
  @State message: string = '';
  @State myId: string = '';
  @State isDrawer: boolean = false;
  @State guessText: string = '';
  @State hasHint: boolean = false;
  @State hintText: ResourceStr = '';
  @State colorIndex: number = 0;
  /** 画布实际尺寸（vp），由可用区域和固定比例算出来。 */
  @State canvasW: number = 320;
  @State canvasH: number = 240;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasReady: boolean = false;
  private strokes: string[] = [];
  private pending: number[][] = [];
  private pendingNew: boolean = true;
  private tickId: number = -1;
  private lastPoint: number[] = [];

  aboutToAppear(): void {
    const session: RoomSession = RoomSession.get();
    this.myId = session.selfId;
    session.onState = (payload: string) => {
      this.applyState(payload);
    };
    session.onEvent = (kind: string, msg: string) => {
      if (kind === DrawEvent.ENDED) {
        this.finished = true;
      }
    };
    if (session.gamePayload.length > 0) {
      this.applyState(session.gamePayload);
    }
    // 本地秒表：服务器每次状态变化会重设秒数，这里负责平滑倒数
    this.tickId = setInterval(() => {
      if (!this.finished && this.secondsLeft > 0) {
        this.secondsLeft = this.secondsLeft - 1;
      }
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.tickId !== -1) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
  }

  private applyState(payload: string): void {
    let state: DrawState;
    try {
      state = JSON.parse(payload) as DrawState;
    } catch (err) {
      return;
    }
    this.phase = state.phase;
    this.round = state.round;
    this.totalRounds = state.totalRounds;
    this.drawerId = state.drawerId;
    this.drawerName = state.drawerName;
    this.word = state.word;
    this.wordMask = state.wordMask;
    this.wordLength = state.wordLength;
    this.candidates = state.candidates;
    this.players = state.players;
    this.secondsLeft = state.secondsLeft;
    this.finished = state.finished;
    this.message = state.message;
    this.myId = RoomSession.get().selfId;
    this.isDrawer = this.myId.length > 0 && this.myId === state.drawerId;
    this.strokes = state.strokes;
    this.redraw();
  }

  private onEvent(): void {
  }

  // ---------- 画布 ----------

  private redraw(): void {
    if (!this.canvasReady) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    const cw: number = this.canvasW;
    const ch: number = this.canvasH;
    ctx.clearRect(0, 0, cw, ch);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, cw, ch);

    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    let prev: number[] = [];
    for (const raw of this.strokes) {
      let seg: DrawSeg;
      try {
        seg = JSON.parse(raw) as DrawSeg;
      } catch (err) {
        continue;
      }
      ctx.strokeStyle = seg.c;
      ctx.lineWidth = seg.w;
      if (seg.p.length === 0) {
        continue;
      }
      ctx.beginPath();
      if (seg.n || prev.length === 0) {
        ctx.moveTo(seg.p[0][0] * cw, seg.p[0][1] * ch);
      } else {
        ctx.moveTo(prev[0] * cw, prev[1] * ch);
      }
      for (const pt of seg.p) {
        ctx.lineTo(pt[0] * cw, pt[1] * ch);
      }
      ctx.stroke();
      if (seg.p.length === 1) {
        // 单点也要留下一个圆点
        ctx.beginPath();
        ctx.arc(seg.p[0][0] * cw, seg.p[0][1] * ch, seg.w / 2, 0, Math.PI * 2);
        ctx.fillStyle = seg.c;
        ctx.fill();
      }
      prev = seg.p[seg.p.length - 1];
    }
  }

  /**
   * 在 w×h 的可用区域里取最大的 4:3 内接矩形。
   * 返回 [宽, 高]。区域本身比 4:3 窄时以宽度为准，反之以高度为准。
   */
  private fitCanvas(w: number, h: number): number[] {
    let cw: number = w;
    let ch: number = w / CANVAS_ASPECT;
    if (ch > h) {
      ch = h;
      cw = h * CANVAS_ASPECT;
    }
    return [cw, ch];
  }

  /** 猜词方在答案揭晓前才知道字数。 */
  private showCountHint(): boolean {
    return !this.isDrawer && this.word.length === 0 && this.wordLength > 0;
  }

  private canDraw(): boolean {
    return this.isDrawer && this.phase === DrawPhase.DRAWING;
  }

  private pushPoint(nx: number, ny: number): void {
    this.pending.push([nx, ny]);
    this.lastPoint = [nx, ny];
    if (this.pending.length >= FLUSH_POINTS) {
      this.flush(false);
    }
  }

  private flush(endOfStroke: boolean): void {
    if (this.pending.length === 0) {
      return;
    }
    const seg: DrawSeg = new DrawSeg();
    seg.w = BRUSH_WIDTH;
    seg.c = PALETTE[this.colorIndex];
    seg.p = this.pending;
    seg.n = this.pendingNew;
    RoomSession.get().sendInputText('stroke', 0, 0, JSON.stringify(seg));
    this.pending = [];
    this.pendingNew = endOfStroke;
  }

  private clearCanvas(): void {
    RoomSession.get().sendInputText('clear', 0, 0, '');
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

  private guess(): void {
    const text: string = this.guessText.trim();
    if (text.length === 0) {
      return;
    }
    RoomSession.get().sendInputText('guess', 0, 0, text);
    this.guessText = '';
  }

  private choose(text: string): void {
    RoomSession.get().sendInputText('choose', 0, 0, text);
  }

  // ---------- 文案 ----------

  private phaseText(): Resource {
    if (this.phase === DrawPhase.CHOOSING) {
      return $r('app.string.dg_phase_choosing');
    }
    if (this.phase === DrawPhase.DRAWING) {
      return $r('app.string.dg_phase_drawing');
    }
    if (this.phase === DrawPhase.REVEAL) {
      return $r('app.string.dg_phase_reveal');
    }
    return $r('app.string.dg_phase_ended');
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 12 }) {
          // 左：画布
          Column() {
            Canvas(this.ctx)
              .width(this.canvasW)
              .height(this.canvasH)
              .backgroundColor($r('app.color.bg_surface'))
              .borderRadius($r('app.float.radius_card'))
              .onReady(() => {
                this.canvasReady = true;
                this.redraw();
              })
              .onTouch((event: TouchEvent) => {
                if (!this.canDraw() || event.touches.length === 0) {
                  return;
                }
                const t: TouchObject = event.touches[0];
                const nx: number = t.x / this.canvasW;
                const ny: number = t.y / this.canvasH;
                if (nx < 0 || nx > 1 || ny < 0 || ny > 1) {
                  return;
                }
                if (event.type === TouchType.Down) {
                  this.pendingNew = true;
                  this.pending = [];
                  this.pushPoint(nx, ny);
                } else if (event.type === TouchType.Move) {
                  this.pushPoint(nx, ny);
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.flush(true);
                }
              })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onAreaChange((oldArea: Area, newArea: Area) => {
            const w: number = Number(newArea.width);
            const h: number = Number(newArea.height);
            if (w <= 0 || h <= 0) {
              return;
            }
            const fit: number[] = this.fitCanvas(w - 8, h - 8);
            if (Math.abs(fit[0] - this.canvasW) > 1 || Math.abs(fit[1] - this.canvasH) > 1) {
              this.canvasW = fit[0];
              this.canvasH = fit[1];
              this.redraw();
            }
          })

          // 右：状态与操作（中段可滚动，底部按钮固定，避免内容多了把按钮挤出去）
          Column({ space: 8 }) {
            Scroll() {
              Column({ space: 8 }) {
            Text($r('app.string.game_drawguess'))
              .fontSize($r('app.float.font_title'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            Row() {
              Text($r('app.string.dg_round'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              Text(this.round.toString() + ' / ' + this.totalRounds.toString())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text($r('app.string.dg_seconds'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              Text(this.secondsLeft.toString())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.warning'))
            }
            .width('100%')

            Row({ space: 6 }) {
              Text(this.phaseText())
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.brand'))
              Text(this.isDrawer ? $r('app.string.dg_you_draw') : $r('app.string.dg_drawing_by'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
              Text(this.isDrawer ? '—' : this.drawerName)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')

            // 词：画手看到真词，其他人看到词长占位
            Column({ space: 4 }) {
              Text(this.isDrawer ? $r('app.string.dg_your_word') : $r('app.string.dg_word'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
              Text(this.word.length > 0 ? this.word : this.wordMask)
                .fontSize($r('app.float.font_title'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent_drawguess'))
                .width('100%')
              // 只有猜词方、且答案还没揭晓时才提示字数
              if (this.showCountHint()) {
                Row({ space: 4 }) {
                  Text($r('app.string.dg_word_count_pre'))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                  Text(this.wordLength.toString())
                    .fontSize($r('app.float.font_caption'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.accent_drawguess'))
                  Text($r('app.string.dg_word_count_suf'))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .alignItems(VerticalAlign.Center)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            if (this.message.length > 0) {
              Text(this.message)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.success'))
                .width('100%')
            }

            Divider().color($r('app.color.border_subtle'))

            Column({ space: 6 }) {
                ForEach(this.players, (p: DrawPlayerView) => {
                  Row({ space: 8 }) {
                    Text(p.isDrawer ? '✎' : '●')
                      .fontSize(12)
                      .fontColor(p.isDrawer ? $r('app.color.accent_drawguess') : $r('app.color.text_disabled'))
                    Text(p.nickname)
                      .fontSize($r('app.float.font_body'))
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (p.guessed) {
                      Text($r('app.string.dg_guessed'))
                        .fontSize($r('app.float.font_caption'))
                        .fontColor($r('app.color.success'))
                    }
                    Text(p.score.toString())
                      .fontSize($r('app.float.font_caption'))
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .width('100%')
                  .height(28)
                  .alignItems(VerticalAlign.Center)
                  // key 里必须带上会变的值：ArkUI 的 ForEach 只在 key 变化时重建条目，
                  // 只用 id 的话分数和「已猜对」永远不会刷新。
                }, (p: DrawPlayerView) => p.id + '/' + p.score.toString() + '/' + (p.guessed ? '1' : '0'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .layoutWeight(1)
            .align(Alignment.Top)

            // 画手选词：紧凑 chip，横排三个
            if (this.isDrawer && this.phase === DrawPhase.CHOOSING) {
              Text($r('app.string.dg_choose_hint'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
              Row({ space: 8 }) {
                ForEach(this.candidates, (c: string) => {
                  Text(c)
                    .fontSize($r('app.float.font_body'))
                    .fontColor($r('app.color.text_on_brand'))
                    .textAlign(TextAlign.Center)
                    .height(40)
                    .layoutWeight(1)
                    .backgroundColor($r('app.color.brand'))
                    .borderRadius($r('app.float.radius_chip'))
                    .onClick(() => {
                      this.choose(c);
                    })
                }, (c: string) => c)
              }
              .width('100%')
            }

            // 画手的画笔颜色与清空
            if (this.canDraw()) {
              Row({ space: 8 }) {
                ForEach(PALETTE, (c: string, idx: number) => {
                  Circle({ width: 26, height: 26 })
                    .fill(c)
                    .stroke(this.colorIndex === idx ? '#3B6FF5' : '#E3E6EB')
                    .strokeWidth(this.colorIndex === idx ? 3 : 1)
                    .onClick(() => {
                      this.colorIndex = idx;
                    })
                }, (c: string) => c)
              }
              .width('100%')

              AppButton({
                label: $r('app.string.dg_clear'),
                primary: false,
                active: true,
                onTap: () => {
                  this.clearCanvas();
                }
              })
            }

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
          .width($r('app.float.sidebar_width_narrow'))
          .height('100%')
          .padding($r('app.float.card_padding'))
          .alignItems(HorizontalAlign.Start)
          .backgroundColor($r('app.color.bg_surface'))
          .borderRadius($r('app.float.radius_card'))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 8, right: 8, top: 8 })

        // 猜词栏横跨整个页面宽度 —— 放在窄侧栏里输入框会小得没法用
        if (!this.isDrawer && this.phase === DrawPhase.DRAWING) {
          Row({ space: 8 }) {
            TextInput({ text: this.guessText, placeholder: $r('app.string.dg_guess_ph') })
              .height($r('app.float.button_height'))
              .layoutWeight(1)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_disabled'))
              .backgroundColor($r('app.color.bg_surface'))
              .borderRadius($r('app.float.radius_input'))
              .padding({ left: 12, right: 12 })
              .onChange((v: string) => {
                this.guessText = v;
              })
              .onSubmit(() => {
                this.guess();
              })
            Column() {
              AppButton({
                label: $r('app.string.dg_guess_submit'),
                primary: true,
                active: this.guessText.trim().length > 0,
                onTap: () => {
                  this.guess();
                }
              })
            }
            .width(110)
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 4, bottom: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
    }
    .hideTitleBar(true)
  }
}
