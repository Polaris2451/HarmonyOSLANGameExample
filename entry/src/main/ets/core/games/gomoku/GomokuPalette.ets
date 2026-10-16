/**
 * 棋盘用的颜色。
 * ArkUI 的 Canvas 只接受 CSS 颜色字符串，不能直接使用 $r() 资源，
 * 所以这里单独列一份，取值与 resources/base/element/color.json 的同名 token 保持一致。
 * 改颜色时两边一起改。
 */
export class BoardPalette {
  static readonly boardBg: string = '#FFF6E6';
  static readonly line: string = '#C8AE86';
  static readonly star: string = '#8A7554';
  static readonly black: string = '#22252B';
  static readonly white: string = '#FFFFFF';
  static readonly edge: string = '#9AA3B2';
  static readonly last: string = '#E5484D';
}
