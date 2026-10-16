/**
 * 统一顶栏：左侧返回、中间标题、可选右侧动作。
 * 六个页面都用它，保证页头完全一致。
 */
@Component
export struct TopBar {
  @Prop title: ResourceStr = '';
  @Prop showBack: boolean = true;
  @Prop rightText: ResourceStr = '';
  @Prop showRight: boolean = false;
  onBack: () => void = () => {};
  onRight: () => void = () => {};

  build() {
    Row() {
      if (this.showBack) {
        Row() {
          Text('←')
            .fontSize($r('app.float.font_title'))
            .fontColor($r('app.color.text_primary'))
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_input'))
        .onClick(() => {
          this.onBack();
        })
      }

      Text(this.title)
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: this.showBack ? 4 : 8 })

      if (this.showRight) {
        Text(this.rightText)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.brand'))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius($r('app.float.radius_input'))
          .onClick(() => {
            this.onRight();
          })
      }
    }
    .width('100%')
    .height($r('app.float.topbar_height'))
    .alignItems(VerticalAlign.Center)
    .padding({ left: 8, right: 8 })
  }
}
