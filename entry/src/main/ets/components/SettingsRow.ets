/**
 * 设置页的一行：左侧标题与说明，右侧任意控件。
 * 右侧内容通过尾随闭包传入（单个 @BuilderParam）。
 */
@Component
export struct SettingsRow {
  @Prop label: ResourceStr = '';
  @Prop hint: ResourceStr = '';
  @Prop showHint: boolean = false;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Row({ space: 16 }) {
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
        if (this.showHint) {
          Text(this.hint)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.content()
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }
}
