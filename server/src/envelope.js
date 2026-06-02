// 统一响应信封，匹配 App 端 ApiResponse<T>：{ success, data, error }
function ok(data) {
  return { success: true, data: data === undefined ? null : data, error: null };
}

function fail(error, code) {
  return { success: false, data: null, error: error, code: code };
}

module.exports = { ok, fail };
