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
    selection: loadSelection,
    grades: loadGrades,
    approvals: loadApprovals,
    notice: () => undefined,
    codes: loadCodes,
    audit: loadAudit,
    db: loadDbTables
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

  // ---------- 选课管理 ----------

  const ROUND_LABEL = {
    notStarted: ['未开始', 'info'],
    running: ['进行中 · 选课开放', 'ok'],
    paused: ['已暂停 · 选课关闭', 'warn'],
    ended: ['已结束 · 选课关闭', 'bad']
  };

  async function loadSelection() {
    const wrap = $('#selection-list');
    wrap.innerHTML = '<div class="empty">加载中…</div>';
    try {
      const rounds = await api('/admin/selection/stats');
      if (rounds.length === 0) {
        wrap.innerHTML = '<div class="empty">暂无选课轮次（可在数据库管理的 selection_rounds 表新增）</div>';
        return;
      }
      wrap.innerHTML = rounds.map((r) => roundCardHtml(r)).join('');
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  function roundCardHtml(r) {
    const st = ROUND_LABEL[r.status] || [r.status, 'info'];
    const actions = [];
    if (r.status === 'notStarted' || r.status === 'paused') {
      actions.push(`<button class="btn btn-success" data-ract="running" data-id="${esc(r.id)}">${r.status === 'paused' ? '恢复开放选课' : '启动选课'}</button>`);
    }
    if (r.status === 'running') {
      actions.push(`<button class="btn" data-ract="paused" data-id="${esc(r.id)}">暂停（关闭选课）</button>`);
    }
    if (r.status === 'running' || r.status === 'paused') {
      actions.push(`<button class="btn btn-danger" data-ract="ended" data-id="${esc(r.id)}">结束（关闭选课）</button>`);
    }
    if (r.status !== 'ended') {
      actions.push(`<button class="btn" data-ract="time" data-id="${esc(r.id)}">编辑起止时间</button>`);
    }
    return `<div class="task-card" id="round-${esc(r.id)}">
      <div class="task-head">
        <span class="title">${esc(r.name)}</span>
        <span class="pill ${st[1]}">${esc(st[0])}</span>
      </div>
      <div class="task-sub">${esc(r.startTime)} ~ ${esc(r.endTime)} · 参与 ${r.participantCount} 人 · 选课 ${r.selectionCount} 条 · 人均 ${r.averageCredit} 学分</div>
      <div class="progress"><i style="width:${r.progressPercent}%"></i></div>
      <div class="task-actions">${actions.join('')}</div>
      <div class="score-panel time-panel" hidden>
        <div class="form-row">
          <label>开始时间
            <input type="text" data-tstart value="${esc(r.startTime)}" placeholder="2026-06-01 09:00">
          </label>
          <label>结束时间
            <input type="text" data-tend value="${esc(r.endTime)}" placeholder="2026-06-30 22:00">
          </label>
        </div>
        <div class="task-actions">
          <button class="btn btn-primary" data-ract="save-time" data-id="${esc(r.id)}">保存时间</button>
          <span class="muted" style="margin:0">格式：YYYY-MM-DD HH:mm（北京时间）</span>
        </div>
      </div>
    </div>`;
  }

  $('#selection-list').addEventListener('click', async (ev) => {
    const btn = ev.target.closest('button[data-ract]');
    if (!btn) { return; }
    const id = btn.dataset.id;
    const act = btn.dataset.ract;
    if (act === 'time') {
      const panel = document.querySelector(`#round-${CSS.escape(id)} .time-panel`);
      if (panel) { panel.hidden = !panel.hidden; }
      return;
    }
    if (act === 'save-time') {
      const panel = document.querySelector(`#round-${CSS.escape(id)} .time-panel`);
      const startTime = panel.querySelector('input[data-tstart]').value.trim();
      const endTime = panel.querySelector('input[data-tend]').value.trim();
      btn.disabled = true;
      try {
        await api('/admin/selection/rounds/' + encodeURIComponent(id) + '/time', {
          method: 'PUT', body: { startTime, endTime }
        });
        toast('起止时间已更新');
        loadSelection();
      } catch (e) { toast(e.message); btn.disabled = false; }
      return;
    }
    if (act === 'ended' && !window.confirm('结束为终态，不可重新开放；学生端将立即无法选课。确认结束该轮次？')) { return; }
    btn.disabled = true;
    try {
      await api('/admin/selection/rounds/' + encodeURIComponent(id) + '/status', {
        method: 'PUT', body: { status: act }
      });
      toast(act === 'running' ? '选课已开放' : (act === 'paused' ? '已暂停，选课关闭' : '轮次已结束，选课关闭'));
      loadSelection();
    } catch (e) {
      toast(e.message);
      btn.disabled = false;
    }
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

  // ---------- 验证码监控 ----------

  let codesData = [];
  let codesTimer = 0;

  function fmtTimeSec(value) {
    if (!value) { return ''; }
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) { return String(value); }
    const p = (n) => (n < 10 ? '0' + n : '' + n);
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
  }

  function fmtCountdown(ms) {
    const total = Math.max(0, Math.ceil(ms / 1000));
    const m = Math.floor(total / 60);
    const s = total % 60;
    return `${m}:${s < 10 ? '0' + s : s}`;
  }

  async function loadCodes() {
    const wrap = $('#codes-table');
    wrap.innerHTML = '<div class="empty">加载中…</div>';
    try {
      codesData = await api('/admin/verification-codes');
      $('#codes-updated').textContent = '更新于 ' + fmtTimeSec(Date.now());
      renderCodes();
      // 每秒重绘倒计时；离开本区域后定时器自动停止
      if (!codesTimer) {
        codesTimer = setInterval(() => {
          if ($('#section-codes').hidden) {
            clearInterval(codesTimer);
            codesTimer = 0;
            return;
          }
          renderCodes();
        }, 1000);
      }
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  function renderCodes() {
    const wrap = $('#codes-table');
    const now = Date.now();
    const live = codesData.filter((c) => c.expiresAt > now);
    if (live.length === 0) {
      wrap.innerHTML = '<div class="empty">当前没有有效验证码（用户请求注册 / 找回密码验证码后会出现在这里）</div>';
      return;
    }
    const rows = live.map((c) => {
      const remain = c.expiresAt - now;
      const pill = remain <= 60 * 1000 ? 'bad' : (remain <= 2 * 60 * 1000 ? 'warn' : 'ok');
      return `<tr>
        <td>${esc(c.email)}</td>
        <td>${esc(fmtTimeSec(c.sentAt))}</td>
        <td>${esc(fmtTimeSec(c.expiresAt))}</td>
        <td><span class="pill ${pill}">${fmtCountdown(remain)}</span></td>
        <td>${c.attempts} / ${c.maxAttempts}</td>
      </tr>`;
    }).join('');
    wrap.innerHTML = `<table>
      <thead><tr><th>请求邮箱</th><th>请求时间</th><th>自动销毁时间</th><th>剩余有效期</th><th>已校验次数</th></tr></thead>
      <tbody>${rows}</tbody></table>`;
  }

  $('#codes-refresh').addEventListener('click', loadCodes);

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

  // ---------- 数据库管理 ----------

  const db = { table: '', columns: [], pk: [], offset: 0, limit: 50, total: 0, q: '' };

  // 表的中文名与所属分类（未登记的表自动归入「未分类」）
  const TABLE_META = {
    accounts: ['登录账号', '账号与学籍'],
    student_profiles: ['学生资料', '账号与学籍'],
    admin_profiles: ['管理员资料', '账号与学籍'],
    class_students: ['班级学生名册', '账号与学籍'],
    courses: ['课程目录', '课程与课表'],
    class_schedule_items: ['班级课表', '课程与课表'],
    course_teachers: ['课程教师绑定', '课程与课表'],
    schedule_items: ['个人课表项', '课程与课表'],
    selection_rounds: ['选课轮次', '课程与课表'],
    selections: ['选课记录', '课程与课表'],
    grade_tasks: ['成绩录入任务', '成绩'],
    grades: ['学生成绩', '成绩'],
    evaluation_templates: ['评教问卷模板', '评教'],
    evaluation_tasks: ['评教任务', '评教'],
    evaluation_submissions: ['评教答卷', '评教'],
    notices: ['通知公告', '通知与消息'],
    notice_reads: ['通知已读记录', '通知与消息'],
    message_templates: ['消息模板', '通知与消息'],
    leave_requests: ['请假申请', '请假与审批'],
    approval_instances: ['审批单', '请假与审批'],
    approval_steps: ['审批步骤', '请假与审批'],
    approval_flow_nodes: ['审批流程节点', '请假与审批'],
    feedback_items: ['意见反馈', '反馈与实践'],
    practice_projects: ['实践项目', '反馈与实践'],
    practice_signups: ['实践报名', '反馈与实践'],
    roles: ['角色', '权限与安全'],
    permissions: ['权限项', '权限与安全'],
    role_permissions: ['角色权限关系', '权限与安全'],
    audit_logs: ['审计日志', '权限与安全'],
    security_policy: ['安全策略', '权限与安全'],
    app_settings: ['应用设置', '系统与其他'],
    calendar_events: ['教学日历事件', '系统与其他'],
    attachments: ['附件', '系统与其他'],
    schema_migrations: ['数据库迁移记录', '系统与其他']
  };
  const CATEGORY_ORDER = ['账号与学籍', '课程与课表', '成绩', '评教', '通知与消息', '请假与审批', '反馈与实践', '权限与安全', '系统与其他', '未分类'];

  function tableLabel(name) {
    return (TABLE_META[name] && TABLE_META[name][0]) || name;
  }

  async function loadDbTables() {
    $('#db-detail').hidden = true;
    const wrap = $('#db-tables');
    wrap.hidden = false;
    wrap.innerHTML = '<div class="empty">表清单加载中…</div>';
    try {
      const tables = await api('/admin/db/tables');
      const groups = new Map();
      for (const t of tables) {
        const cat = (TABLE_META[t.name] && TABLE_META[t.name][1]) || '未分类';
        if (!groups.has(cat)) { groups.set(cat, []); }
        groups.get(cat).push(t);
      }
      let html = '';
      for (const cat of CATEGORY_ORDER) {
        const list = groups.get(cat);
        if (!list || list.length === 0) { continue; }
        const cards = list.map((t) => `
          <div class="db-table-card" data-table="${esc(t.name)}">
            <span>
              <span class="tlabel">${esc(tableLabel(t.name))}</span>
              <span class="tname">${esc(t.name)}</span>
            </span>
            <span class="pill info">${t.rows} 行</span>
          </div>`).join('');
        html += `<h3 class="db-cat">${esc(cat)}<small>${list.length} 张表</small></h3><div class="db-cat-grid">${cards}</div>`;
      }
      wrap.innerHTML = html || '<div class="empty">无数据表</div>';
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  $('#db-tables').addEventListener('click', (ev) => {
    const card = ev.target.closest('.db-table-card');
    if (!card) { return; }
    db.table = card.dataset.table;
    db.offset = 0;
    db.q = '';
    $('#db-q').value = '';
    openDbTable();
  });

  async function openDbTable() {
    $('#db-tables').hidden = true;
    $('#db-detail').hidden = false;
    $('#db-editor').hidden = true;
    $('#db-table-title').textContent = `${tableLabel(db.table)}（dtest2.${db.table}）`;
    const wrap = $('#db-rows');
    wrap.innerHTML = '<div class="empty">加载中…</div>';
    try {
      const params = `?limit=${db.limit}&offset=${db.offset}` + (db.q ? '&q=' + encodeURIComponent(db.q) : '');
      const data = await api('/admin/db/tables/' + encodeURIComponent(db.table) + '/rows' + params);
      db.columns = data.columns;
      db.pk = data.pk;
      db.total = data.total;
      renderDbRows(data.rows);
      const page = Math.floor(db.offset / db.limit) + 1;
      const pages = Math.max(1, Math.ceil(db.total / db.limit));
      $('#db-page').textContent = `共 ${db.total} 行 · 第 ${page}/${pages} 页`;
      $('#db-prev').disabled = db.offset === 0;
      $('#db-next').disabled = db.offset + db.limit >= db.total;
    } catch (e) {
      wrap.innerHTML = `<div class="empty">${esc(e.message)}</div>`;
    }
  }

  function cellText(value) {
    if (value === null || value === undefined) { return 'NULL'; }
    if (typeof value === 'object') { return JSON.stringify(value); }
    return String(value);
  }

  function renderDbRows(rows) {
    const wrap = $('#db-rows');
    if (rows.length === 0) {
      wrap.innerHTML = '<div class="empty">无数据</div>';
      return;
    }
    const head = db.columns.map((c) => `<th>${esc(c.name)}${c.pk ? ' 🔑' : ''}</th>`).join('');
    const body = rows.map((row, idx) => {
      const cells = db.columns.map((c) =>
        `<td class="${c.pk ? 'pk-col' : ''}" title="${esc(cellText(row[c.name]))}">${esc(cellText(row[c.name]))}</td>`).join('');
      return `<tr>${cells}<td class="row-ops">
        <button class="btn" data-rop="edit" data-idx="${idx}">编辑</button>
        <button class="btn btn-danger" data-rop="del" data-idx="${idx}">删除</button>
      </td></tr>`;
    }).join('');
    wrap.innerHTML = `<table><thead><tr>${head}<th>操作</th></tr></thead><tbody>${body}</tbody></table>`;
    wrap.dataset.rows = JSON.stringify(rows);
  }

  $('#db-back').addEventListener('click', loadDbTables);
  $('#db-search').addEventListener('click', () => { db.q = $('#db-q').value.trim(); db.offset = 0; openDbTable(); });
  $('#db-q').addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { $('#db-search').click(); } });
  $('#db-prev').addEventListener('click', () => { db.offset = Math.max(0, db.offset - db.limit); openDbTable(); });
  $('#db-next').addEventListener('click', () => { db.offset += db.limit; openDbTable(); });
  $('#db-add').addEventListener('click', () => openDbEditor(null));

  $('#db-rows').addEventListener('click', async (ev) => {
    const btn = ev.target.closest('button[data-rop]');
    if (!btn) { return; }
    const rows = JSON.parse($('#db-rows').dataset.rows || '[]');
    const row = rows[Number(btn.dataset.idx)];
    if (!row) { return; }
    if (btn.dataset.rop === 'edit') { return openDbEditor(row); }
    // 删除
    const pkDesc = db.pk.map((k) => `${k}=${cellText(row[k])}`).join(', ');
    if (!window.confirm(`确认删除该行？\n${pkDesc}\n此操作不可恢复。`)) { return; }
    btn.disabled = true;
    try {
      const pkBody = {};
      db.pk.forEach((k) => { pkBody[k] = row[k]; });
      await api('/admin/db/tables/' + encodeURIComponent(db.table) + '/rows', { method: 'DELETE', body: { pk: pkBody } });
      toast('已删除');
      openDbTable();
    } catch (e) {
      toast(e.message);
      btn.disabled = false;
    }
  });

  // row=null 表示新增；编辑时主键列只读
  function openDbEditor(row) {
    if (db.pk.length === 0) { return toast('该表无主键，不支持行编辑'); }
    const editor = $('#db-editor');
    const isEdit = row !== null;
    const fields = db.columns.map((c) => {
      const raw = isEdit ? row[c.name] : null;
      const value = raw === null || raw === undefined ? '' : (typeof raw === 'object' ? JSON.stringify(raw) : String(raw));
      const readonly = isEdit && c.pk;
      const hint = `${c.type}${c.pk ? ' · 主键' : ''}${c.nullable ? '' : ' · 必填'}${!isEdit && c.hasDefault ? ' · 留空走默认值' : ''}`;
      return `<label>${esc(c.name)}<small>${esc(hint)}</small>
        <input type="text" data-col="${esc(c.name)}" value="${esc(value)}" ${readonly ? 'readonly style="opacity:.6"' : ''}
               data-wasnull="${raw === null || raw === undefined ? '1' : '0'}">
      </label>`;
    }).join('');
    editor.innerHTML = `<div class="editor-head">${isEdit ? '编辑行' : '新增行'} · ${esc(db.table)}</div>
      ${fields}
      <p class="muted" style="margin:0">编辑时清空字段＝置 NULL；新增时留空＝走默认值/NULL；json 列填 JSON 文本。</p>
      <div class="task-actions">
        <button class="btn" id="db-editor-cancel">取消</button>
        <button class="btn btn-primary" id="db-editor-save">${isEdit ? '保存修改' : '插入行'}</button>
      </div>`;
    editor.hidden = false;
    editor.dataset.mode = isEdit ? 'edit' : 'insert';
    editor.dataset.pkrow = isEdit ? JSON.stringify(db.pk.reduce((acc, k) => { acc[k] = row[k]; return acc; }, {})) : '';
    $('#db-editor-cancel').addEventListener('click', () => { editor.hidden = true; });
    $('#db-editor-save').addEventListener('click', saveDbEditor);
  }

  async function saveDbEditor() {
    const editor = $('#db-editor');
    const isEdit = editor.dataset.mode === 'edit';
    const btn = $('#db-editor-save');
    const values = {};
    for (const input of editor.querySelectorAll('input[data-col]')) {
      const col = db.columns.find((c) => c.name === input.dataset.col);
      if (!col) { continue; }
      if (isEdit && col.pk) { continue; }
      const text = input.value;
      if (text === '') {
        if (isEdit) {
          // 原本就是 NULL 且未填 → 不动；原本有值被清空 → 置 NULL
          if (input.dataset.wasnull === '0') { values[col.name] = null; }
        }
        // 新增：留空＝不提交该列（走默认值/NULL）
        continue;
      }
      values[col.name] = text;
    }
    if (Object.keys(values).length === 0) { return toast(isEdit ? '没有需要保存的修改' : '请至少填写一列'); }
    btn.disabled = true;
    try {
      if (isEdit) {
        await api('/admin/db/tables/' + encodeURIComponent(db.table) + '/rows', {
          method: 'PUT', body: { pk: JSON.parse(editor.dataset.pkrow), values }
        });
        toast('已保存修改');
      } else {
        await api('/admin/db/tables/' + encodeURIComponent(db.table) + '/rows', {
          method: 'POST', body: { values }
        });
        toast('已插入新行');
      }
      editor.hidden = true;
      openDbTable();
    } catch (e) {
      toast(e.message);
      btn.disabled = false;
    }
  }

  // ---------- 启动 ----------

  if (sessionStorage.getItem(TOKEN_KEY)) {
    showMain();
  } else {
    showLogin();
  }
})();
