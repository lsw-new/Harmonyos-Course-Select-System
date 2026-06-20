// 离线 IP→地域解析：基于 ip2region（xdb 二进制库，零外部网络依赖）。
// 数据文件随仓库打包在 server/assets/ip2region/ip2region.xdb（约 11MB，已接受）。
// Searcher 以「整库载入内存 buffer」方式构建一次并缓存，后续查询纯内存二分，无磁盘 IO。
//
// 导出 resolveGeo(ip)：返回干净的「省·市」串；私网/回环/非法 IP / 任意查询异常一律返回 ''，绝不抛出。
// 注：底层库 search() 为异步（即便内存 buffer 也返回 Promise），故 resolveGeo 为 async，返回 Promise<string>。
const path = require('path');
const { newWithBuffer, loadContentFromFile, isValidIp } = require('ip2region-ts');

// 随仓库打包的 xdb 路径（优先用 assets 下的副本，与部署解耦，不依赖 node_modules 布局）
const XDB_PATH = path.join(__dirname, '..', 'assets', 'ip2region', 'ip2region.xdb');

// 私网 / 回环 / 链路本地等不可定位的 IPv4 段：直接判空，免去无意义查库。
// 10/8、172.16/12、192.168/16、127/8、169.254/16、100.64/10（CGNAT），以及 0.0.0.0。
function isPrivateOrLoopback(ip) {
  if (!ip) { return true; }
  // IPv6 回环 / IPv4-mapped 回环
  if (ip === '::1' || ip === '::' ) { return true; }
  const m = /^(?:::ffff:)?(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(ip);
  if (!m) { return true; } // 非纯 IPv4（含纯 IPv6 公网）一律按不可定位处理（库仅支持 IPv4）
  const a = Number(m[1]);
  const b = Number(m[2]);
  if (a === 10 || a === 127 || a === 0) { return true; }
  if (a === 172 && b >= 16 && b <= 31) { return true; }
  if (a === 192 && b === 168) { return true; }
  if (a === 169 && b === 254) { return true; }
  if (a === 100 && b >= 64 && b <= 127) { return true; }
  return false;
}

// 整库 buffer 模式的 Searcher（懒加载 + 缓存）；加载失败置为「已尝试但不可用」，后续直接返回 ''。
let searcher;
let loadFailed = false;

function getSearcher() {
  if (searcher) { return searcher; }
  if (loadFailed) { return null; }
  try {
    const buffer = loadContentFromFile(XDB_PATH);
    searcher = newWithBuffer(buffer);
    return searcher;
  } catch (e) {
    loadFailed = true; // 数据文件缺失/损坏：降级为「地点留空」，绝不影响登录/审计主流程
    return null;
  }
}

// ip2region region 串格式：国家|区域|省份|城市|ISP，缺位以 '0' 占位。
// 取「省份·城市」，剔除 '0' 占位与国家/ISP；省市相同（如直辖市）只留一个。
function cleanRegion(region) {
  if (!region) { return ''; }
  const parts = region.split('|').map((s) => (s || '').trim());
  // parts: [国家, 区域, 省份, 城市, ISP]
  const province = parts[2] && parts[2] !== '0' ? parts[2] : '';
  const city = parts[3] && parts[3] !== '0' ? parts[3] : '';
  if (province && city) {
    return province === city ? province : `${province}·${city}`;
  }
  if (province) { return province; }
  if (city) { return city; }
  // 省市皆空时退回国家（仅当非 '0' 且非「中国」内网占位），否则空串
  const country = parts[0] && parts[0] !== '0' ? parts[0] : '';
  return country;
}

async function resolveGeo(ip) {
  try {
    const addr = String(ip || '').trim();
    if (isPrivateOrLoopback(addr) || !isValidIp(addr)) {
      return '';
    }
    const s = getSearcher();
    if (!s) { return ''; }
    const r = await s.search(addr);
    return cleanRegion(r && r.region);
  } catch (e) {
    return ''; // 任何解析异常都不向上抛，地点留空即可
  }
}

module.exports = { resolveGeo, cleanRegion, isPrivateOrLoopback };
