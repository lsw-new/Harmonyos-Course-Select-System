// 请求身份提取（P0-01 越权防护）：当前学生身份一律取自 JWT
// （登录账号即学号，token.sub=account_id=student_id），不再信任客户端
// query/body 传入的 studentId，杜绝 IDOR 水平越权。
function currentStudentId(req) {
  return (req.auth && req.auth.sub) ? String(req.auth.sub) : '';
}

module.exports = { currentStudentId };
