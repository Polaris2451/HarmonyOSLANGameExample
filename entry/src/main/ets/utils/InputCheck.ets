import { PORT_MAX, PORT_MIN } from '../core/Routes';

/** 表单校验的小工具，避免各页面重复实现。 */
export class InputCheck {
  /** 只允许数字，不用正则，避免不同引擎的差异。 */
  static isDigits(text: string): boolean {
    if (text.length === 0) {
      return false;
    }
    for (let i = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  static parsePort(text: string): number {
    if (!InputCheck.isDigits(text)) {
      return -1;
    }
    const value: number = Number.parseInt(text, 10);
    if (Number.isNaN(value) || value < PORT_MIN || value > PORT_MAX) {
      return -1;
    }
    return value;
  }

  static isPortText(text: string): boolean {
    return InputCheck.parsePort(text) > 0;
  }
}
