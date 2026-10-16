/**
 * 带标签、占位符与错误提示的输入框。
 * 错误状态用 danger 描边加下方一行说明，不用弹窗。
 */
@Component
export struct LabeledInput {
  @Prop label: ResourceStr = '';
  @Prop placeholder: ResourceStr = '';
  @Prop text: string = '';
  @Prop hasError: boolean = false;
  @Prop errorText: ResourceStr = '';
  @Prop inputKind: InputType = InputType.Normal;
  @Prop maxLength: number = 32;
  onTextChange: (value: string) => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      TextInput({ text: this.text, placeholder: this.placeholder })
        .type(this.inputKind)
        .maxLength(this.maxLength)
        .height($r('app.float.button_height'))
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_disabled'))
        .backgroundColor($r('app.color.bg_sunken'))
        .borderRadius($r('app.float.radius_input'))
        .padding({ left: 12, right: 12 })
        .borderWidth(this.hasError ? 1 : 0)
        .borderColor($r('app.color.danger'))
        .onChange((value: string) => {
          this.onTextChange(value);
        })

      if (this.hasError) {
        Text(this.errorText)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.danger'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
