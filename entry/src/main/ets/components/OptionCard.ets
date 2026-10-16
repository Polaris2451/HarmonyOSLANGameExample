/**
 * 选项卡片：主入口的三个入口，以及创建房间页的游戏选择。
 * showGlyph=false + cardHeight 调小即为紧凑模式，适配横屏较矮的可用高度。
 */
@Component
export struct OptionCard {
  @Prop title: ResourceStr = '';
  @Prop desc: ResourceStr = '';
  @Prop glyph: string = '';
  @Prop accent: Resource = $r('app.color.brand');
  @Prop softAccent: Resource = $r('app.color.brand_soft');
  @Prop selected: boolean = false;
  @Prop showSelection: boolean = false;
  @Prop showGlyph: boolean = true;
  @Prop cardHeight: number = 148;
  onTap: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      if (this.showGlyph) {
        Row() {
          Text(this.glyph)
            .fontSize(22)
            .fontColor(this.accent)
            .textAlign(TextAlign.Center)
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.softAccent)
        .borderRadius($r('app.float.radius_input'))
      }

      Text(this.title)
        .fontSize($r('app.float.font_subtitle'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.desc)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(this.cardHeight)
    .padding($r('app.float.card_padding'))
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.bg_surface'))
    .borderRadius($r('app.float.radius_card'))
    .border({
      width: this.showSelection && this.selected ? 2 : 1,
      color: this.showSelection && this.selected ? this.accent : $r('app.color.border_subtle')
    })
    .onClick(() => {
      this.onTap();
    })
  }
}
