/**
 * 统一按钮：主按钮（品牌色填充）与次按钮（浅底）两种形态。
 * 禁用时统一使用 disabled_bg / text_disabled，并且不触发点击。
 * 属性名用 active 而不是 enabled，避免与 ArkUI 通用属性 enabled 冲突。
 */
@Component
export struct AppButton {
  @Prop label: ResourceStr = '';
  @Prop primary: boolean = true;
  @Prop active: boolean = true;
  onTap: () => void = () => {};

  build() {
    Button() {
      Text(this.label)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.active
          ? (this.primary ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
          : $r('app.color.text_disabled'))
    }
    .type(ButtonType.Capsule)
    .width('100%')
    .height($r('app.float.button_height'))
    .backgroundColor(this.active
      ? (this.primary ? $r('app.color.brand') : $r('app.color.bg_sunken'))
      : $r('app.color.disabled_bg'))
    .onClick(() => {
      if (this.active) {
        this.onTap();
      }
    })
  }
}
