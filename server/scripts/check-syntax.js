'use strict';
// 轻量 JS 语法门禁：对 src/ test/ scripts/ 下每个 .js 跑 `node --check`（仅解析、不执行）。
// 任一语法错误即非零退出，供 CI 在跑测试前快速拦截。零依赖——不引入 ESLint，CI 用 node 自带能力即可。

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

function collect(dir, acc) {
  if (!fs.existsSync(dir)) {
    return acc;
  }
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.name === 'node_modules' || ent.name === 'coverage') {
      continue;
    }
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      collect(full, acc);
    } else if (ent.name.endsWith('.js')) {
      acc.push(full);
    }
  }
  return acc;
}

const files = [];
for (const sub of ['src', 'test', 'scripts']) {
  collect(path.join(root, sub), files);
}
// 根级独立脚本（迁移 / 种子数据 / 入口）
for (const name of ['migrate.js', 'seed.js', 'index.js']) {
  const p = path.join(root, name);
  if (fs.existsSync(p)) {
    files.push(p);
  }
}

let failed = 0;
for (const file of files) {
  try {
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' });
  } catch (e) {
    failed += 1;
    process.stderr.write(`✗ 语法错误：${path.relative(root, file)}\n`);
    if (e.stderr) {
      process.stderr.write(e.stderr.toString());
    }
  }
}

if (failed > 0) {
  process.stderr.write(`\n语法检查失败：${failed} 个文件存在语法错误。\n`);
  process.exit(1);
}
process.stdout.write(`✓ 语法检查通过：${files.length} 个 JS 文件无语法错误。\n`);
