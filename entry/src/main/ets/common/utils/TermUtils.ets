// 学期与教学周计算

export class TermUtils {
  // 用学期开始日期与今天计算教学周
  static currentWeek(termStart: string, today: Date = new Date()): number {
    const start = new Date(termStart).getTime();
    const ms = today.getTime() - start;
    if (ms < 0) {
      return 0;
    }
    return Math.floor(ms / (7 * 86400000)) + 1;
  }

  static weekRange(termStart: string, weekIndex: number): string[] {
    const start = new Date(termStart);
    start.setDate(start.getDate() + (weekIndex - 1) * 7);
    const result: string[] = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(start);
      d.setDate(start.getDate() + i);
      const m = (d.getMonth() + 1).toString().padStart(2, '0');
      const dd = d.getDate().toString().padStart(2, '0');
      result.push(`${m}/${dd}`);
    }
    return result;
  }

  static defaultTermLabel(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    if (month >= 9 || month <= 1) {
      const startYear = month >= 9 ? year : year - 1;
      return `${startYear}-${startYear + 1} 学年 第一学期`;
    }
    if (month >= 2 && month <= 8) {
      const startYear = year - 1;
      return `${startYear}-${startYear + 1} 学年 第二学期`;
    }
    return `${year} 学年`;
  }
}
