#!/usr/bin/env node
/*
 * 前端 ArkTS 静态检查门禁（纯 Node，无第三方依赖）。
 *
 * 背景：HarmonyOS HAP 的真实编译/Hypium 测试需要 DevEco Studio SDK，
 * GitHub 托管 runner 没有该 SDK，无法在托管 runner 上构建 HAP。
 * 因此本脚本只做「始终可用」的静态门禁：递归扫描 entry/src/main/ets
 * 下所有 .ets 文件，检测我们真实踩过的 ArkTS 破坏性写法。
 *
 * 硬失败（命中即 exit 1）：
 *   1) 对象字面量展开 `{ ... }`        —— ArkTS 禁止对象 spread（数组 [...arr] 不算）。
 *   2) VerticalAlign.Stretch           —— 不存在的枚举。
 * 仅 WARN（不失败，避免存量误杀）：
 *   - console.log(   - : any   - as any
 *
 * 本地等价命令：node scripts/ci/check-frontend.js
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const SCAN_DIR = path.join(ROOT, 'entry', 'src', 'main', 'ets');

// 硬失败规则
const HARD_RULES = [
  {
    name: 'object-spread',
    // 匹配 `{` 后紧跟可选空格再 `...` 再跟标识符/字符串/方括号，即真正的对象字面量展开 `{ ...obj }`。
    // - 数组展开 `[...arr]` 前一个字符是 `[` 而非 `{`，不会命中。
    // - 注释/文档里的省略号 `{ ... }`、`{...}`（`...` 后是空格或 `}`）不会命中。
    re: /\{\s*\.\.\.[A-Za-z_$['"]/,
    msg: 'ArkTS 禁止对象字面量展开 `{ ... }`，请改用显式字段拷贝',
  },
  {
    name: 'vertical-align-stretch',
    re: /VerticalAlign\.Stretch/,
    msg: 'VerticalAlign.Stretch 不存在，请使用有效枚举（Top/Center/Bottom）',
  },
];

// 仅警告规则
const WARN_RULES = [
  { name: 'console-log', re: /console\.log\(/, msg: '存在 console.log（建议移除调试输出）' },
  { name: 'type-any', re: /:\s*any\b/, msg: '存在 `: any` 类型标注（建议改为具体类型）' },
  { name: 'as-any', re: /\bas\s+any\b/, msg: '存在 `as any` 断言（建议改为具体类型）' },
];

function listEtsFiles(dir) {
  const out = [];
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    return out;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...listEtsFiles(full));
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      out.push(full);
    }
  }
  return out;
}

function rel(file) {
  return path.relative(ROOT, file).split(path.sep).join('/');
}

function main() {
  if (!fs.existsSync(SCAN_DIR)) {
    console.error(`[check-frontend] 扫描目录不存在：${rel(SCAN_DIR)}`);
    process.exit(1);
  }

  const files = listEtsFiles(SCAN_DIR);
  const hardHits = [];
  const warnHits = [];

  for (const file of files) {
    const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
    lines.forEach((line, idx) => {
      const lineNo = idx + 1;
      for (const rule of HARD_RULES) {
        if (rule.re.test(line)) {
          hardHits.push({ file: rel(file), line: lineNo, rule: rule.name, msg: rule.msg });
        }
      }
      for (const rule of WARN_RULES) {
        if (rule.re.test(line)) {
          warnHits.push({ file: rel(file), line: lineNo, rule: rule.name, msg: rule.msg });
        }
      }
    });
  }

  for (const hit of warnHits) {
    console.log(`WARN  ${hit.file}:${hit.line}:${hit.rule}  ${hit.msg}`);
  }
  for (const hit of hardHits) {
    console.error(`ERROR ${hit.file}:${hit.line}:${hit.rule}  ${hit.msg}`);
  }

  console.log('');
  console.log('--- check-frontend 汇总 ---');
  console.log(`扫描文件数：${files.length}`);
  console.log(`硬失败：${hardHits.length}    警告：${warnHits.length}`);

  if (hardHits.length > 0) {
    console.error(`检查未通过：发现 ${hardHits.length} 处 ArkTS 破坏性写法。`);
    process.exit(1);
  }
  console.log('检查通过：未发现 ArkTS 破坏性写法。');
  process.exit(0);
}

main();
