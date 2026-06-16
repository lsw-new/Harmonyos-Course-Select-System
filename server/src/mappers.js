'use strict';
// 纯数据映射 + SQL 列/查询常量（从 index.js 抽出）。
// 全部为零副作用的纯函数：行(row) → App 端对象，不依赖 pool / req / res。
// 周次解析与冲突判定与前端 CourseRepository 同源，保证前后端口径一致。

const WEEKDAY_CN = ['', '一', '二', '三', '四', '五', '六', '日'];

function deriveTimeText(row) {
  if (row.weekday && row.period_start && row.period_end) {
    const cn = WEEKDAY_CN[row.weekday] || String(row.weekday);
    return `周${cn} ${row.period_start}-${row.period_end} 节`;
  }
  return row.weeks_text || '';
}

// 解析课程周次文本（形如 "1-16 周" / "2-15 周" / "1,3,5 周" / "1-8,10-16"）为周次数组。
function parseCourseWeeks(weeksStr) {
  const out = [];
  const cleaned = String(weeksStr || '').replace(/[^0-9,\-]/g, '');
  if (!cleaned) {
    return out;
  }
  for (const tok of cleaned.split(',')) {
    if (!tok) {
      continue;
    }
    const dash = tok.indexOf('-');
    if (dash > 0) {
      const a = parseInt(tok.slice(0, dash), 10);
      const b = parseInt(tok.slice(dash + 1), 10);
      if (!Number.isNaN(a) && !Number.isNaN(b)) {
        for (let w = a; w <= b; w++) {
          if (out.indexOf(w) < 0) {
            out.push(w);
          }
        }
      }
    } else {
      const w = parseInt(tok, 10);
      if (!Number.isNaN(w) && out.indexOf(w) < 0) {
        out.push(w);
      }
    }
  }
  return out;
}

// 两门课是否时间冲突：同一星期、节次区间重叠、且周次有交集。未排课（weekday/period 缺失）不参与冲突判定。
function coursesConflict(a, b) {
  const wda = Number(a.weekday);
  const wdb = Number(b.weekday);
  if (!wda || !wdb || wda < 1 || wdb < 1) {
    return false;
  }
  if (wda !== wdb) {
    return false;
  }
  const psa = Number(a.period_start);
  const pea = Number(a.period_end);
  const psb = Number(b.period_start);
  const peb = Number(b.period_end);
  if (!psa || !pea || !psb || !peb) {
    return false;
  }
  if (psa > peb || psb > pea) {
    return false;
  }
  const wa = parseCourseWeeks(a.weeks_text);
  const wb = parseCourseWeeks(b.weeks_text);
  for (const w of wa) {
    if (wb.indexOf(w) >= 0) {
      return true;
    }
  }
  return false;
}

function mapCourse(row) {
  return {
    id: row.course_id,
    code: row.code,
    name: row.name,
    teacher: row.teacher,
    category: row.category,
    credit: Number(row.credit),
    timeText: deriveTimeText(row),
    capacity: row.capacity,
    selectedCount: Number(row.selected_count || 0),
    status: row.status,
    targetGrade: row.target_grade || ''
  };
}

const COURSE_COLUMNS =
  `c.course_id, c.code, c.name, c.teacher, c.category, c.credit, c.capacity, c.status,
   c.weekday, c.period_start, c.period_end, c.weeks_text, c.target_grade`;
const SELECTED_COUNT_JOIN =
  `LEFT JOIN (SELECT course_id, COUNT(*) cnt FROM dtest2.selections WHERE status='selected' GROUP BY course_id) sc
     ON sc.course_id = c.course_id`;

function mapNotice(row) {
  return {
    id: row.notice_id,
    title: row.title,
    publisher: row.publisher,
    publishedAt: row.published_at,
    summary: row.summary || '',
    content: row.content,
    isRead: row.is_read === true,
    category: row.category,
    urgency: row.urgency || 'normal',
    attachments: []
  };
}

function mapLeave(row) {
  return {
    id: row.leave_id,
    type: row.type,
    startDate: row.start_date,
    endDate: row.end_date,
    reason: row.reason,
    attachments: [],
    state: row.status,
    submittedAt: row.submitted_at,
    feedback: row.feedback || ''
  };
}

function mapFeedback(row) {
  return {
    id: row.feedback_id,
    category: row.category,
    title: row.title,
    content: row.content,
    contact: row.contact || '',
    screenshots: [],
    submittedAt: row.submitted_at,
    state: row.state,
    reply: row.reply || '',
    repliedBy: row.replied_by || '',
    repliedByName: row.replied_by_name || '',
    repliedAt: row.replied_at || '',
    studentId: row.student_id || '',
    studentName: row.student_name || ''
  };
}

function mapEval(row) {
  return {
    id: row.task_id,
    term: row.term,
    courseCode: row.code || '',
    courseName: row.name || '',
    courseCategory: row.category || '',
    teacherName: row.teacher_name || '',
    questionnaireName: row.questionnaire_name || '教学质量评价问卷',
    status: row.status,
    openTime: row.open_time || '',
    closeTime: row.close_time || ''
  };
}

function mapPractice(row) {
  return {
    id: row.project_id,
    title: row.title,
    org: row.org,
    category: row.category,
    credits: Number(row.credits),
    period: row.period,
    location: row.location || '',
    mentor: row.mentor || '',
    slotsTotal: row.slots_total,
    slotsTaken: Number(row.slots_taken || 0),
    signedUp: row.signed_up === true,
    description: row.description || '',
    requirements: Array.isArray(row.requirements_json) ? row.requirements_json : []
  };
}

const PRACTICE_SELECT =
  `SELECT p.project_id, p.title, p.org, p.category, p.credits, p.period, p.location, p.mentor,
          p.slots_total, p.description, p.requirements_json,
          COALESCE(st.cnt, 0) AS slots_taken,
          CASE WHEN ms.project_id IS NULL THEN false ELSE true END AS signed_up
   FROM dtest2.practice_projects p
   LEFT JOIN (SELECT project_id, COUNT(*) cnt FROM dtest2.practice_signups WHERE status='signedUp' GROUP BY project_id) st
     ON st.project_id = p.project_id
   LEFT JOIN dtest2.practice_signups ms ON ms.project_id = p.project_id AND ms.student_id = $1 AND ms.status='signedUp'`;

function leaveTypeLabel(type) {
  if (type === 'sick') return '病假';
  if (type === 'personal') return '事假';
  if (type === 'public') return '公假';
  return '其他';
}

function mapStudent(row) {
  return {
    studentId: row.student_id,
    name: row.name,
    college: row.college,
    major: row.major,
    className: row.class_name,
    status: 'active',
    educationLevel: 'undergraduate'
  };
}

function mapGradeTask(row) {
  const item = {
    id: row.task_id,
    courseName: row.course_name || '',
    teachingClassName: row.teaching_class_name,
    teacherName: row.teacher_name,
    inputProgress: row.input_progress,
    status: row.status,
    updatedAt: row.updated_at
  };
  if (row.reject_reason) {
    item.rejectReason = row.reject_reason;
  }
  return item;
}

function mapApproval(row) {
  return {
    id: row.approval_id,
    type: row.biz_type === 'leave' ? '请假' : row.biz_type,
    applicantName: row.applicant_name,
    applicantId: row.applicant_id,
    title: row.title,
    reason: row.reason || '',
    status: row.status,
    isUrgent: row.is_urgent === true,
    submittedAt: row.submitted_at
  };
}

function mapAuditLog(row) {
  return {
    id: row.log_id,
    operatorName: row.operator_name || '',
    operatorId: row.operator_id || '',
    action: row.action,
    actionType: row.action_type,
    target: row.target,
    timestamp: row.created_at,
    result: row.result,
    ip: row.ip || ''
  };
}

function mapTemplate(row) {
  return {
    id: row.template_id,
    name: row.name,
    description: row.description || '',
    questionCount: row.question_count,
    status: row.status
  };
}

module.exports = {
  WEEKDAY_CN,
  deriveTimeText,
  parseCourseWeeks,
  coursesConflict,
  mapCourse,
  COURSE_COLUMNS,
  SELECTED_COUNT_JOIN,
  mapNotice,
  mapLeave,
  mapFeedback,
  mapEval,
  mapPractice,
  PRACTICE_SELECT,
  leaveTypeLabel,
  mapStudent,
  mapGradeTask,
  mapApproval,
  mapAuditLog,
  mapTemplate
};
