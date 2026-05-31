// 课表导入服务 · 以「学生课表 xlsx（教务导出）」为模板
// 解析链路：xlsx(zip) --@ohos.zlib--> 解压 --读取 xl/sharedStrings.xml + xl/worksheets/sheet1.xml--> 解析网格 --> ScheduleItem[]
// 纯解析函数 parseSchedule() 不依赖任何系统能力，可单测。

import zlib from '@ohos.zlib';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import { ScheduleItem } from '../../models/Course';

interface RawOffering {
  name: string;
  code: string;
  teacher: string;
  weeksStr: string;
  loc: string;
}

interface StrCell {
  col: string;
  row: number;
  idx: number;
}

// 第 1-10 节的起止时间（与项目既有课表时段一致，晚间扩展 9-10 节）。
const START_TIMES: string[] = ['', '08:00', '08:50', '10:00', '10:50', '14:00', '14:50', '16:00', '16:50', '19:00', '19:50'];
const END_TIMES: string[] = ['', '08:45', '09:35', '10:45', '11:35', '14:45', '15:35', '16:45', '17:35', '19:45', '20:35'];

export const DEFAULT_TERM: string = '2025-2026-2';

// 导入安全边界：仅接受 .xlsx，限制压缩包体积，避免不可信文件耗尽内存。
const ALLOWED_EXT: string = '.xlsx';
const MAX_IMPORT_FILE_SIZE: number = 5 * 1024 * 1024; // 5 MB

export class ScheduleImportService {
  // ============ 纯解析（可单测） ============

  static parseSchedule(sharedStringsXml: string, sheetXml: string, term: string): ScheduleItem[] {
    const strings: string[] = ScheduleImportService.parseSharedStrings(sharedStringsXml);
    const merges: Map<string, number> = ScheduleImportService.parseMerges(sheetXml);
    const cells: StrCell[] = ScheduleImportService.parseStringCells(sheetXml);

    const items: ScheduleItem[] = [];
    let counter: number = 0;
    for (const c of cells) {
      const weekday: number = c.col.charCodeAt(0) - 65; // A=0,B=1...G=6,H=7
      if (weekday < 1 || weekday > 6) {
        continue; // 仅周一至周六（周日列为空）
      }
      if (c.row < 5 || c.row > 14) {
        continue; // 节次行 5-14 → 第 1-10 节
      }
      const mergeKey: string = c.col + c.row;
      const endRow: number = merges.has(mergeKey) ? merges.get(mergeKey)! : c.row;
      const periodStart: number = c.row - 4;
      const periodEnd: number = endRow - 4;
      const text: string = (c.idx >= 0 && c.idx < strings.length) ? strings[c.idx] : '';
      const offerings: RawOffering[] = ScheduleImportService.parseOfferings(text);
      for (const o of offerings) {
        const weeks: number[] = ScheduleImportService.expandWeeks(o.weeksStr);
        if (weeks.length === 0) {
          continue;
        }
        counter++;
        const stype: 'normal' | 'practice' = o.name.indexOf('实践') >= 0 ? 'practice' : 'normal';
        let campus: string | undefined = undefined;
        if (o.loc.indexOf('芗苑') >= 0) {
          campus = '芗苑校区';
        } else if (o.loc.indexOf('茶苑') >= 0) {
          campus = '茶苑校区';
        }
        const item: ScheduleItem = {
          id: 'imp-' + counter,
          term: term,
          type: stype,
          courseId: o.code.split('.')[0],
          courseName: o.name,
          teacher: o.teacher,
          weekday: weekday,
          periodStart: periodStart,
          periodEnd: periodEnd,
          startTime: ScheduleImportService.timeAt(START_TIMES, periodStart),
          endTime: ScheduleImportService.timeAt(END_TIMES, periodEnd),
          classroom: o.loc.length > 0 ? o.loc : '待定',
          campus: campus,
          weeks: weeks,
          weekText: o.weeksStr + ' 周',
          courseType: ScheduleImportService.inferType(o.code)
        };
        items.push(item);
      }
    }
    return ScheduleImportService.dedupeAndSort(items);
  }

  private static timeAt(table: string[], period: number): string {
    if (period >= 1 && period < table.length) {
      return table[period];
    }
    return '';
  }

  private static inferType(code: string): string {
    return code.indexOf('VDZ') === 0 ? '必修' : '公选';
  }

  private static dedupeAndSort(items: ScheduleItem[]): ScheduleItem[] {
    const seen: string[] = [];
    const result: ScheduleItem[] = [];
    for (const it of items) {
      const key: string = it.weekday + '|' + it.periodStart + '-' + it.periodEnd + '|' + it.courseId + '|' + it.weekText + '|' + it.classroom;
      if (seen.indexOf(key) >= 0) {
        continue;
      }
      seen.push(key);
      result.push(it);
    }
    result.sort((a: ScheduleItem, b: ScheduleItem) =>
      a.weekday - b.weekday || a.periodStart - b.periodStart);
    for (let i = 0; i < result.length; i++) {
      result[i].id = 'imp-' + (i + 1);
    }
    return result;
  }

  private static unescapeXml(s: string): string {
    return s
      .replace(/&#10;/g, '\n').replace(/&#13;/g, '\r')
      .replace(/&#xA;/g, '\n').replace(/&#xD;/g, '\r')
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&apos;/g, "'")
      .replace(/&amp;/g, '&');
  }

  private static parseSharedStrings(xml: string): string[] {
    const out: string[] = [];
    const siRe: RegExp = /<si>([\s\S]*?)<\/si>/g;
    let m: RegExpExecArray | null = siRe.exec(xml);
    while (m !== null) {
      const inner: string = m[1];
      const tRe: RegExp = /<t[^>]*>([\s\S]*?)<\/t>/g;
      let s: string = '';
      let tm: RegExpExecArray | null = tRe.exec(inner);
      while (tm !== null) {
        s += ScheduleImportService.unescapeXml(tm[1]);
        tm = tRe.exec(inner);
      }
      out.push(s);
      m = siRe.exec(xml);
    }
    return out;
  }

  private static parseMerges(xml: string): Map<string, number> {
    const map: Map<string, number> = new Map<string, number>();
    const re: RegExp = /<mergeCell ref="([A-Z]+)(\d+):([A-Z]+)(\d+)"\/>/g;
    let m: RegExpExecArray | null = re.exec(xml);
    while (m !== null) {
      map.set(m[1] + m[2], parseInt(m[4], 10));
      m = re.exec(xml);
    }
    return map;
  }

  private static parseStringCells(xml: string): StrCell[] {
    const cells: StrCell[] = [];
    const re: RegExp = /<c r="([A-Z]+)(\d+)"[^>]*?t="s"[^>]*?><v>(\d+)<\/v><\/c>/g;
    let m: RegExpExecArray | null = re.exec(xml);
    while (m !== null) {
      const cell: StrCell = { col: m[1], row: parseInt(m[2], 10), idx: parseInt(m[3], 10) };
      cells.push(cell);
      m = re.exec(xml);
    }
    return cells;
  }

  private static parseOfferings(text: string): RawOffering[] {
    const out: RawOffering[] = [];
    const rawLines: string[] = text.split(/\r?\n/);
    const lines: string[] = [];
    for (const l of rawLines) {
      const t: string = l.trim();
      if (t.length > 0) {
        lines.push(t);
      }
    }
    const nameRe: RegExp = /^(.+?)\s*\(([A-Za-z0-9.]+)\)\s*\(([^()]+)\)$/;
    for (let i = 0; i < lines.length; i++) {
      const nm: RegExpExecArray | null = nameRe.exec(lines[i]);
      if (nm === null) {
        continue;
      }
      let weeksStr: string = '';
      let loc: string = '';
      const info: string = (i + 1 < lines.length) ? lines[i + 1] : '';
      if (info.length > 0 && info.charAt(0) === '(') {
        let inner: string = info.substring(1);
        if (inner.length > 0 && inner.charAt(inner.length - 1) === ')') {
          inner = inner.substring(0, inner.length - 1);
        }
        const sp: number = inner.indexOf(' ');
        if (sp >= 0) {
          weeksStr = inner.substring(0, sp);
          loc = inner.substring(sp + 1).trim();
        } else {
          weeksStr = inner;
          loc = '';
        }
        i++;
      }
      const off: RawOffering = {
        name: nm[1].trim(),
        code: nm[2],
        teacher: nm[3].trim(),
        weeksStr: weeksStr,
        loc: loc
      };
      out.push(off);
    }
    return out;
  }

  static expandWeeks(s: string): number[] {
    const out: number[] = [];
    const tokens: string[] = s.split(',');
    const rangeRe: RegExp = /^(\d+)-(\d+)(单|双)?$/;
    const singleRe: RegExp = /^(\d+)$/;
    for (const tok of tokens) {
      const t: string = tok.trim();
      const rm: RegExpExecArray | null = rangeRe.exec(t);
      if (rm !== null) {
        const a: number = parseInt(rm[1], 10);
        const b: number = parseInt(rm[2], 10);
        const par: string = rm[3] !== undefined ? rm[3] : '';
        for (let w = a; w <= b; w++) {
          if (par === '单' && w % 2 === 0) {
            continue;
          }
          if (par === '双' && w % 2 === 1) {
            continue;
          }
          if (out.indexOf(w) < 0) {
            out.push(w);
          }
        }
        continue;
      }
      const sm: RegExpExecArray | null = singleRe.exec(t);
      if (sm !== null) {
        const w: number = parseInt(sm[1], 10);
        if (out.indexOf(w) < 0) {
          out.push(w);
        }
      }
    }
    out.sort((x: number, y: number) => x - y);
    return out;
  }

  // ============ 设备侧读取（解压 + 选择文件） ============

  // 从应用内置 rawfile（李仕炜课表，作为模板/示例）导入。
  static async importBundledSchedule(context: common.UIAbilityContext, term: string): Promise<ScheduleItem[]> {
    const bytes: Uint8Array = await context.resourceManager.getRawFileContent('my_schedule.xlsx');
    return ScheduleImportService.importFromBuffer(context, bytes.buffer as ArrayBuffer, term);
  }

  // 让用户选择一个 .xlsx 文件并导入。
  static async pickAndImportSchedule(context: common.UIAbilityContext, term: string): Promise<ScheduleItem[]> {
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    const uris: string[] = await documentPicker.select(options);
    if (uris.length === 0) {
      throw new Error('未选择文件');
    }
    const uri: string = uris[0];
    if (!uri.toLowerCase().endsWith(ALLOWED_EXT)) {
      throw new Error('仅支持学校官方课表模板（.xlsx 文件）');
    }
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      if (stat.size <= 0) {
        throw new Error('课表文件为空');
      }
      if (stat.size > MAX_IMPORT_FILE_SIZE) {
        throw new Error('课表文件过大（上限 5 MB），请确认是否为官方课表模板');
      }
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      return await ScheduleImportService.importFromBuffer(context, buf, term);
    } finally {
      fs.closeSync(file);
    }
  }

  private static async importFromBuffer(context: common.UIAbilityContext, buffer: ArrayBuffer, term: string): Promise<ScheduleItem[]> {
    // 每次导入使用独立临时目录，避免并发/重复导入互相覆盖
    const unique: string = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    const workDir: string = `${context.cacheDir}/schedule_import_${unique}`;
    const zipPath: string = `${workDir}/source.zip`;
    const outDir: string = `${workDir}/out`;

    fs.mkdirSync(workDir);
    try {
      fs.mkdirSync(outDir);

      // 写入临时 zip
      const zf = fs.openSync(zipPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(zf.fd, buffer);
      } finally {
        fs.closeSync(zf);
      }

      await zlib.decompressFile(zipPath, outDir);

      const ssPath: string = outDir + '/xl/sharedStrings.xml';
      const sheetPath: string = outDir + '/xl/worksheets/sheet1.xml';
      if (!fs.accessSync(ssPath) || !fs.accessSync(sheetPath)) {
        throw new Error('课表文件格式不正确（缺少工作表数据）');
      }
      const ss: string = fs.readTextSync(ssPath);
      const sheet: string = fs.readTextSync(sheetPath);
      const items: ScheduleItem[] = ScheduleImportService.parseSchedule(ss, sheet, term);
      if (items.length === 0) {
        throw new Error('未从该课表中解析到任何课程');
      }
      return items;
    } finally {
      // 无论成功失败都清理临时目录（含 zip 与解压产物）
      try {
        fs.rmdirSync(workDir);
      } catch (e) {
        // 目录已不存在则忽略
      }
    }
  }
}
