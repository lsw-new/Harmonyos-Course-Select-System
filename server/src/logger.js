'use strict';
// 零依赖结构化日志（项目惯例手写中间件，不引 winston/pino/morgan）。
// 输出单行：`[dtest2-api] <LEVEL> <ISO时间> <msg> <JSON.stringify(meta||{})>`。
// info/warn 走 stdout，error 走 stderr。
// NODE_ENV==='test' 时静默（不打印），但函数仍正常返回，便于测试调用覆盖且不污染测试输出。

const TAG = '[dtest2-api]';

// 纯函数：拼装日志行，供单测直接断言格式，不产生副作用。
function formatLine(level, msg, meta) {
  const safeMeta = (meta === undefined || meta === null) ? {} : meta;
  let metaText;
  try {
    metaText = JSON.stringify(safeMeta);
  } catch (e) {
    // 循环引用等 stringify 失败时降级，绝不让日志本身抛错中断业务。
    metaText = '{}';
  }
  return `${TAG} ${level} ${new Date().toISOString()} ${msg} ${metaText}`;
}

function emit(stream, level, msg, meta) {
  const line = formatLine(level, msg, meta);
  if (process.env.NODE_ENV !== 'test') {
    stream.write(line + '\n');
  }
  return line;
}

function info(msg, meta) {
  return emit(process.stdout, 'INFO', msg, meta);
}

function warn(msg, meta) {
  return emit(process.stdout, 'WARN', msg, meta);
}

function error(msg, meta) {
  return emit(process.stderr, 'ERROR', msg, meta);
}

module.exports = { info, warn, error, formatLine };
