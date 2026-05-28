// 日期工具

export class DateUtils {
  static pad2(n: number): string {
    return n < 10 ? `0${n}` : String(n);
  }

  static format(date: Date, pattern: string = 'yyyy-MM-dd'): string {
    const y = date.getFullYear();
    const m = DateUtils.pad2(date.getMonth() + 1);
    const d = DateUtils.pad2(date.getDate());
    const hh = DateUtils.pad2(date.getHours());
    const mm = DateUtils.pad2(date.getMinutes());
    const ss = DateUtils.pad2(date.getSeconds());
    return pattern
      .replace('yyyy', String(y))
      .replace('MM', m)
      .replace('dd', d)
      .replace('HH', hh)
      .replace('mm', mm)
      .replace('ss', ss);
  }

  static today(): string {
    return DateUtils.format(new Date());
  }

  static now(): string {
    return DateUtils.format(new Date(), 'yyyy-MM-dd HH:mm:ss');
  }

  static daysBetween(a: string, b: string): number {
    const da = new Date(a).getTime();
    const db = new Date(b).getTime();
    return Math.round((db - da) / 86400000);
  }

  static weekdayLabel(weekday: number): string {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    return labels[weekday % 7];
  }
}
