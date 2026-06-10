// 教学管理系统 · 后端管理控制台
// 纯前端单页：直接调用现有 dtest2 管理端 API（JWT + 细粒度权限由后端校验）。
(function () {
  'use strict';

  const API = '/api';
  const TOKEN_KEY = 'dtest2.admin.token';
  const PROFILE_KEY = 'dtest2.admin.profile';

  const $ = (sel) => document.querySelector(sel);

  // ---------- 工具 ----------

  function esc(value) {
    return String(value === null || value === undefined ? '' : value)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  let toastTimer = 0;
  function toast(msg) {
    const el = $('#toast');
    el.textContent = msg;
    el.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { el.hidden = true; }, 2600);
  }

  function fmtTime(value) {
    if (!value) { return ''; }
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) { return String(value); }
    const p = (n) => (n < 10 ? '0' + n : '' + n);
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  }

  // ---------- API ----------

  async function api(path, options) {
    const opts = options || {};
    const headers = { 'Content-Type': 'application/json' };
    const token = sessionStorage.getItem(TOKEN_KEY);
    if (token) { headers.Authorization = 'Bearer ' + token; }
    let res;
    try {
      res = await fetch(API + path, {
        method: opts.method || 'GET',
        headers,
        body: opts.body ? JSON.stringify(opts.body) : undefined
      });
    } catch (e) {
      throw new Error('网络异常，请检查连接');
    }
    if (res.status === 401) {
      logout();
      throw new Error('登录已过期，请重新登录');
    }
    let payload = null;
    try { payload = await res.json(); } catch (e) { /* 非 JSON 响应 */ }
    if (!res.ok || !payload || payload.success === false) {
      throw new Error((payload && payload.error) || `请求失败（${res.status}）`);
    }
    return payload.data;
  }

  // ---------- 登录 / 会话 ----------

  function showLogin() {
    $('#view-login').hidden = false;
    $('#view-main').hidden = true;
  }

  function showMain() {
    $('#view-login').hidden = true;
    $('#view-main').hidden = false;
    const profile = JSON.parse(sessionStorage.getItem(PROFILE_KEY) || '{}');
    $('#admin-info').innerHTML = `<strong>${esc(profile.name || '管理员')}</strong><br>${esc(profile.department || '')}<br>${esc(profile.adminId || '')}`;
    switchSection('overview');
  }

  function logout() {
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(PROFILE_KEY);
    showLogin();
  }

  $('#login-form').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const btn = $('#login-btn');
    const errEl = $('#login-error');
    errEl.hidden = true;
    btn.disabled = true;
    btn.textContent = '登录中…';
    try {
      const data = await api('/auth/login', {
        method: 'POST',
        body: { account: $('#login-account').value.trim(), password: $('#login-password').value }
      });
      const role = (data.profile && data.profile.role) || data.role || '';
      if (role !== 'admin') {
        throw new Error('该账号不是管理员，无法进入控制台');
      }
      sessionStorage.setItem(TOKEN_KEY, data.token);
      sessionStorage.setItem(PROFILE_KEY, JSON.stringify(data.profile || {}));
      showMain();
    } catch (e) {
      errEl.textContent = e.message;
      errEl.hidden = false;
    } finally {
      btn.disabled = false;
      btn.textContent = '登 录';
    }
  });

  $('#logout-btn').addEventListener('click', logout);

  // ---------- 导航 ----------

  const loaders = {
    overview: loadOverview,
    students: () => loadStudents(''),
    grades: loadGrades,
    approvals: loadApprovals,
    notice: () => undefined,
    audit: loadAudit
  };

  function switchSection(name) {
    document.querySelectorAll('.nav-item').forEach((b) => b.classList.toggle('active', b.dataset.section === name));
    document.querySelectorAll('.section').forEach((s) => { s.hidden = s.id !== 'section-' + name; });
    const load = loaders[name];
    if (load) { load(); }
  }

  $('#nav').addEventListener('click', (ev) => {
    const btn = ev.target.closest('.nav-item');
    if (btn) { switchSection(btn.dataset.section); }
  });

  // ---------- 概览 ----------

  async function loadOverview() {
    const wrap = $('#overview-cards');
    wrap.innerHTML = '<div class="empty">统计加载中…</div>';
    try {
      const [students, grades, approvals] = await Promise.all([
        api('/admin/students'),
        api('/admin/grades'),
        api('/admin/approvals?status=pending')
      ]);
      const published = grades.filter((g) => g.status === 'published').length;
      const pendingAudit = grades.filter((g) => g.status === 'pendingAudit').length;
      wrap.innerHTML = `
        <div class="stat-card"><div class="num">${students.length}</div><div class="lbl">已注册学生</div></div>
        <div class="stat-card alt"><div class="num">${grades.length}</div><div class="lbl">成绩任务（课程）</div></div>
        <div class="stat-card gold"><div class="num">${pendingAudit}</div><div class="lbl">成绩待审核</div></div>
        <div class="stat-card"><div class="num">${published}</div><div class="lbl">成绩已发布</div></div>
        <div class="stat-card alt"><div class="num">${approvals.length}</div><div class="lbl">待处理审批</div></div>`;
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  // ---------- 学生管理 ----------

  async function loadStudents(q) {
    const wrap = $('#students-table');
    wrap.innerHTML = '<div class="empty">加载中…</div>';
    try {
      const list = await api('/admin/students' + (q ? '?q=' + encodeURIComponent(q) : ''));
      if (list.length === 0) {
        wrap.innerHTML = '<div class="empty">未找到学生（学生注册后出现在此列表）</div>';
        return;
      }
      const rows = list.map((s) => `
        <tr>
          <td>${esc(s.studentId)}</td><td>${esc(s.name)}</td>
          <td>${esc(s.className)}</td><td>${esc(s.grade || '')}</td>
          <td>${esc(s.college)}</td><td>${esc(s.major)}</td>
        </tr>`).join('');
      wrap.innerHTML = `<table>
        <thead><tr><th>学号</th><th>姓名</th><th>班级</th><th>年级</th><th>学院</th><th>专业</th></tr></thead>
        <tbody>${rows}</tbody></table>`;
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  $('#student-search').addEventListener('click', () => loadStudents($('#student-q').value.trim()));
  $('#student-q').addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter') { loadStudents($('#student-q').value.trim()); }
  });

  // ---------- 成绩打分 ----------

  const STATUS_LABEL = {
    inputting: ['录入中', 'info'],
    pendingAudit: ['待审核', 'warn'],
    published: ['已发布', 'ok'],
    rejected: ['已驳回', 'bad'],
    appealed: ['异议', 'info']
  };

  async function loadGrades() {
    const wrap = $('#grades-list');
    wrap.innerHTML = '<div class="empty">加载中…</div>';
    try {
      const tasks = await api('/admin/grades');
      if (tasks.length === 0) {
        wrap.innerHTML = '<div class="empty">暂无成绩任务</div>';
        return;
      }
      wrap.innerHTML = tasks.map((t) => taskCardHtml(t)).join('');
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  function taskCardHtml(t) {
    const st = STATUS_LABEL[t.status] || [t.status, 'info'];
    const actions = [];
    if (t.status !== 'published') {
      actions.push(`<button class="btn btn-primary" data-act="score" data-id="${esc(t.id)}">按学生打分</button>`);
    }
    if (t.status === 'pendingAudit') {
      actions.push(`<button class="btn btn-success" data-act="approve" data-id="${esc(t.id)}">审核通过（发布）</button>`);
      actions.push(`<button class="btn btn-danger" data-act="reject" data-id="${esc(t.id)}">驳回</button>`);
    }
    const rejectInfo = t.rejectReason ? `<div class="task-sub" style="color:var(--danger)">驳回理由：${esc(t.rejectReason)}</div>` : '';
    return `<div class="task-card" id="task-${esc(t.id)}">
      <div class="task-head">
        <span class="title">${esc(t.courseName)}</span>
        <span class="pill ${st[1]}">${esc(st[0])}</span>
      </div>
      <div class="task-sub">${esc(t.teachingClassName)} · ${esc(t.teacherName)} · 录入 ${t.inputProgress}% · ${esc(fmtTime(t.updatedAt))}</div>
      ${rejectInfo}
      <div class="progress"><i style="width:${t.inputProgress}%"></i></div>
      <div class="task-actions">${actions.join('')}</div>
      <div class="score-panel" hidden></div>
    </div>`;
  }

  $('#grades-list').addEventListener('click', async (ev) => {
    const btn = ev.target.closest('button[data-act]');
    if (!btn) { return; }
    const id = btn.dataset.id;
    const act = btn.dataset.act;
    if (act === 'score') { return toggleScorePanel(id); }
    if (act === 'approve') {
      if (!window.confirm('审核通过后成绩将对学生发布，确认？')) { return; }
      btn.disabled = true;
      try {
        await api('/admin/grades/' + encodeURIComponent(id) + '/approve', { method: 'POST' });
        toast('已审核通过，成绩已发布');
        loadGrades();
      } catch (e) { toast(e.message); btn.disabled = false; }
      return;
    }
    if (act === 'reject') {
      const reason = window.prompt('请填写驳回理由：');
      if (!reason || !reason.trim()) { return; }
      btn.disabled = true;
      try {
        await api('/admin/grades/' + encodeURIComponent(id) + '/reject', { method: 'POST', body: { reason: reason.trim() } });
        toast('已驳回');
        loadGrades();
      } catch (e) { toast(e.message); btn.disabled = false; }
      return;
    }
    if (act === 'save-scores') { return saveScores(id, btn); }
  });

  async function toggleScorePanel(taskId) {
    const panel = document.querySelector(`#task-${CSS.escape(taskId)} .score-panel`);
    if (!panel) { return; }
    if (!panel.hidden) { panel.hidden = true; return; }
    panel.hidden = false;
    panel.innerHTML = '<div class="empty">打分名单加载中…</div>';
    try {
      const data = await api('/admin/grades/' + encodeURIComponent(taskId) + '/scores');
      if (data.students.length === 0) {
        panel.innerHTML = '<div class="empty">本班暂无已注册学生，学生注册后即可打分</div>';
        return;
      }
      const rows = data.students.map((s) => `
        <div class="score-row">
          <span class="name">${esc(s.name)}</span>
          <span class="sid">${esc(s.studentId)}</span>
          <input type="number" min="0" max="100" step="0.5" placeholder="分数"
                 data-sid="${esc(s.studentId)}" value="${s.score === null ? '' : esc(s.score)}">
        </div>`).join('');
      panel.innerHTML = `${rows}
        <div class="task-actions" style="margin-top:10px">
          <button class="btn btn-primary" data-act="save-scores" data-id="${esc(taskId)}">保存打分</button>
          <span class="muted" style="margin:0">留空＝暂不打分；全部打完自动转待审核</span>
        </div>`;
    } catch (e) {
      panel.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  async function saveScores(taskId, btn) {
    const panel = document.querySelector(`#task-${CSS.escape(taskId)} .score-panel`);
    const inputs = panel.querySelectorAll('input[data-sid]');
    const scores = [];
    for (const input of inputs) {
      const text = input.value.trim();
      if (text === '') { continue; }
      const value = Number(text);
      if (!Number.isFinite(value) || value < 0 || value > 100) {
        return toast('分数需为 0-100 的数字');
      }
      scores.push({ studentId: input.dataset.sid, score: value });
    }
    if (scores.length === 0) { return toast('请先填写至少一名学生的分数'); }
    btn.disabled = true;
    try {
      const updated = await api('/admin/grades/' + encodeURIComponent(taskId) + '/scores', {
        method: 'POST', body: { scores }
      });
      toast(updated.inputProgress === 100 ? '打分完成，已转待审核' : `已保存 ${scores.length} 人（进度 ${updated.inputProgress}%）`);
      loadGrades();
    } catch (e) {
      toast(e.message);
      btn.disabled = false;
    }
  }

  // ---------- 审批中心 ----------

  const APPROVAL_LABEL = { pending: ['待处理', 'warn'], approved: ['已通过', 'ok'], rejected: ['已驳回', 'bad'], withdrawn: ['已撤回', 'info'] };

  async function loadApprovals() {
    const wrap = $('#approvals-list');
    wrap.innerHTML = '<div class="empty">加载中…</div>';
    const status = $('#approval-status').value;
    try {
      const list = await api('/admin/approvals' + (status ? '?status=' + encodeURIComponent(status) : ''));
      if (list.length === 0) {
        wrap.innerHTML = '<div class="empty">暂无审批记录</div>';
        return;
      }
      wrap.innerHTML = list.map((a) => {
        const st = APPROVAL_LABEL[a.status] || [a.status, 'info'];
        const ops = a.status === 'pending' ? `
          <textarea rows="2" placeholder="审批意见（必填）" data-comment="${esc(a.id)}"></textarea>
          <div class="task-actions">
            <button class="btn btn-success" data-aact="approve" data-id="${esc(a.id)}">通过</button>
            <button class="btn btn-danger" data-aact="reject" data-id="${esc(a.id)}">驳回</button>
          </div>` : '';
        return `<div class="approval-card">
          <div class="task-head">
            <span class="title">${esc(a.title)}${a.isUrgent ? ' <span class="pill bad">加急</span>' : ''}</span>
            <span class="pill ${st[1]}">${esc(st[0])}</span>
          </div>
          <div class="meta">${esc(a.type)} · ${esc(a.applicantName)}（${esc(a.applicantId)}）· ${esc(fmtTime(a.submittedAt))}<br>事由：${esc(a.reason || '—')}</div>
          ${ops}
        </div>`;
      }).join('');
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  $('#approval-refresh').addEventListener('click', loadApprovals);
  $('#approvals-list').addEventListener('click', async (ev) => {
    const btn = ev.target.closest('button[data-aact]');
    if (!btn) { return; }
    const id = btn.dataset.id;
    const comment = (document.querySelector(`textarea[data-comment="${CSS.escape(id)}"]`) || {}).value || '';
    if (!comment.trim()) { return toast('请填写审批意见'); }
    btn.disabled = true;
    try {
      await api('/admin/approvals/' + encodeURIComponent(id) + '/' + btn.dataset.aact, {
        method: 'POST', body: { comment: comment.trim() }
      });
      toast(btn.dataset.aact === 'approve' ? '已通过' : '已驳回');
      loadApprovals();
    } catch (e) {
      toast(e.message);
      btn.disabled = false;
    }
  });

  // ---------- 通知发布 ----------

  $('#notice-form').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const msgEl = $('#notice-msg');
    msgEl.hidden = true;
    const btn = ev.target.querySelector('button[type="submit"]');
    btn.disabled = true;
    try {
      await api('/admin/notices', {
        method: 'POST',
        body: {
          title: $('#notice-title').value.trim(),
          content: $('#notice-content').value.trim(),
          category: $('#notice-category').value.trim() || '通知',
          urgency: $('#notice-urgency').value,
          receiverType: $('#notice-receiver').value
        }
      });
      toast('通知已发布，学生端通知列表可见');
      $('#notice-title').value = '';
      $('#notice-content').value = '';
    } catch (e) {
      msgEl.textContent = e.message;
      msgEl.hidden = false;
    } finally {
      btn.disabled = false;
    }
  });

  // ---------- 审计日志 ----------

  async function loadAudit() {
    const wrap = $('#audit-table');
    wrap.innerHTML = '<div class="empty">加载中…</div>';
    try {
      const list = await api('/admin/audit-logs');
      if (list.length === 0) {
        wrap.innerHTML = '<div class="empty">暂无日志</div>';
        return;
      }
      const rows = list.map((l) => `
        <tr>
          <td>${esc(fmtTime(l.timestamp))}</td><td>${esc(l.operatorName)}</td>
          <td>${esc(l.action)}</td><td>${esc(l.target)}</td>
          <td><span class="pill ${l.result === 'success' ? 'ok' : 'bad'}">${l.result === 'success' ? '成功' : '失败'}</span></td>
          <td>${esc(l.ip || '')}</td>
        </tr>`).join('');
      wrap.innerHTML = `<table>
        <thead><tr><th>时间</th><th>操作人</th><th>操作</th><th>对象</th><th>结果</th><th>IP</th></tr></thead>
        <tbody>${rows}</tbody></table>`;
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  // ---------- 启动 ----------

  if (sessionStorage.getItem(TOKEN_KEY)) {
    showMain();
  } else {
    showLogin();
  }
})();
