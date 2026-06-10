// 学期与教学周计算

export class TermUtils {
  // 本学期（2025-2026 第二学期）总周数 = 20。
  // 依据《景德镇艺术职业大学 2025-2026 学年校历》：周次一至二十（第20周止于 7 月 19 日），
  // 其中期末集中考试 6/29-7/1（第18周）、校外实践教学周 7/2-7/10、学生暑假 7/11 起。
  static readonly TERM_WEEKS: number = 20;

  // 本学期第 1 教学周周一（本地时区构造，避免 ISO 串按 UTC 解析造成周一早晨差一周）。
  // 校历第二学期周次「一」= 3 月 2 日（周一）—— 与锚点 2026-03-02 一致。
  static termStart(): Date {
    return new Date(2026, 2, 2);
  }

  // 当前教学周（按今天与学期第 1 周周一的差值计算，夹在 1..TERM_WEEKS 内）
  static teachingWeek(today: Date = new Date()): number {
    const ms = today.getTime() - TermUtils.termStart().getTime();
    const w = Math.floor(ms / (7 * 86400000)) + 1;
    if (w < 1) {
      return 1;
    }
    return w > TermUtils.TERM_WEEKS ? TermUtils.TERM_WEEKS : w;
  }

  // 第 weekIndex 教学周的周一（本地时区）
  static weekMonday(weekIndex: number): Date {
    const d = TermUtils.termStart();
    d.setDate(d.getDate() + (weekIndex - 1) * 7);
    return d;
  }

  // 第 weekIndex 教学周周一的 YYYY-MM-DD 文本
  static weekStartDateText(weekIndex: number): string {
    const d = TermUtils.weekMonday(weekIndex);
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd = d.getDate().toString().padStart(2, '0');
    return `${d.getFullYear()}-${m}-${dd}`;
  }

  // 第 weekIndex 教学周周一到周日的 MM/DD 文本（共 7 项）
  static weekDatesOf(weekIndex: number): string[] {
    const monday = TermUtils.weekMonday(weekIndex);
    const result: string[] = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      const m = (d.getMonth() + 1).toString().padStart(2, '0');
      const dd = d.getDate().toString().padStart(2, '0');
      result.push(`${m}/${dd}`);
    }
    return result;
  }

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
