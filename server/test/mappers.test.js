'use strict';

const {
  deriveTimeText,
  parseCourseWeeks,
  coursesConflict,
  mapCourse,
  mapNotice,
  mapLeave,
  mapFeedback,
  mapEval,
  mapPractice,
  leaveTypeLabel,
  mapStudent,
  mapGradeTask,
  mapApproval,
  mapAuditLog,
  mapTemplate
} = require('../src/mappers');

describe('mappers pure helpers', () => {
  test('deriveTimeText formats scheduled rows and falls back to weeks text', () => {
    expect(deriveTimeText({ weekday: 1, period_start: 3, period_end: 4 })).toBe('周一 3-4 节');
    expect(deriveTimeText({ weekday: 9, period_start: 1, period_end: 2 })).toBe('周9 1-2 节');
    expect(deriveTimeText({ weeks_text: '1-16 周' })).toBe('1-16 周');
    expect(deriveTimeText({})).toBe('');
  });

  test('parseCourseWeeks ignores empty and invalid tokens while preserving unique weeks', () => {
    expect(parseCourseWeeks(undefined)).toEqual([]);
    expect(parseCourseWeeks('1-3,3,5,,8-,10-10 周')).toEqual([1, 2, 3, 5, 10]);
    expect(parseCourseWeeks('3-1 周')).toEqual([]);
  });

  test('coursesConflict requires same weekday, overlapping periods, and shared weeks', () => {
    const base = { weekday: 2, period_start: 3, period_end: 4, weeks_text: '1-8 周' };

    expect(coursesConflict({ ...base, weekday: 0 }, base)).toBe(false);
    expect(coursesConflict(base, { ...base, weekday: 3 })).toBe(false);
    expect(coursesConflict(base, { ...base, period_start: undefined })).toBe(false);
    expect(coursesConflict(base, { ...base, period_start: 5, period_end: 6 })).toBe(false);
    expect(coursesConflict(base, { ...base, period_start: 4, period_end: 5, weeks_text: '9-12 周' })).toBe(false);
    expect(coursesConflict(base, { ...base, period_start: 4, period_end: 5, weeks_text: '8-12 周' })).toBe(true);
  });

  test('maps course rows with selected count defaults and schedule-derived time text', () => {
    expect(mapCourse({
      course_id: 'c1', code: 'ART101', name: '陶瓷艺术', teacher: '李老师', category: '必修', credit: '2.5',
      weekday: 4, period_start: 1, period_end: 2, capacity: 40, status: 'open'
    })).toEqual({
      id: 'c1', code: 'ART101', name: '陶瓷艺术', teacher: '李老师', category: '必修', credit: 2.5,
      timeText: '周四 1-2 节', capacity: 40, selectedCount: 0, status: 'open'
    });

    expect(mapCourse({
      course_id: 'c2', code: 'ART102', name: '雕塑', teacher: '王老师', category: '选修', credit: 1,
      weeks_text: '2-10 周', capacity: 20, selected_count: '7', status: 'closed'
    }).selectedCount).toBe(7);
  });

  test('maps common student-facing rows with optional defaults', () => {
    expect(mapNotice({
      notice_id: 'n1', title: '通知', publisher: '教务处', published_at: '2026-06-09', content: '正文',
      is_read: false, category: '教学'
    })).toMatchObject({ id: 'n1', summary: '', isRead: false, attachments: [] });

    expect(mapLeave({
      leave_id: 'l1', type: 'sick', start_date: '2026-06-09', end_date: '2026-06-10', reason: '身体不适',
      status: 'pending', submitted_at: '2026-06-09'
    })).toMatchObject({ id: 'l1', feedback: '', attachments: [] });

    expect(mapFeedback({
      feedback_id: 'f1', category: '教学', title: '建议', content: '内容', submitted_at: '2026-06-09', state: 'open'
    })).toMatchObject({ id: 'f1', contact: '', screenshots: [] });
  });

  test('maps evaluation and practice rows with fallback fields', () => {
    expect(mapEval({ task_id: 'e1', term: '2025-2026-2', status: 'open' })).toEqual({
      id: 'e1', term: '2025-2026-2', courseCode: '', courseName: '', courseCategory: '', teacherName: '',
      questionnaireName: '教学质量评价问卷', status: 'open', openTime: '', closeTime: ''
    });

    expect(mapPractice({
      project_id: 'p1', title: '实践', org: '学院', category: '创新', credits: '1.5', period: '暑期',
      slots_total: 10, signed_up: true, requirements_json: ['提交报告']
    })).toMatchObject({
      id: 'p1', credits: 1.5, location: '', mentor: '', slotsTaken: 0, signedUp: true,
      description: '', requirements: ['提交报告']
    });

    expect(mapPractice({
      project_id: 'p2', title: '实践2', org: '学院', category: '劳动', credits: 1, period: '春季',
      slots_total: 5, slots_taken: '2', signed_up: false, requirements_json: null
    })).toMatchObject({ slotsTaken: 2, signedUp: false, requirements: [] });
  });

  test('maps administrative labels and optional branches', () => {
    expect(leaveTypeLabel('sick')).toBe('病假');
    expect(leaveTypeLabel('personal')).toBe('事假');
    expect(leaveTypeLabel('public')).toBe('公假');
    expect(leaveTypeLabel('other')).toBe('其他');

    expect(mapStudent({
      student_id: 's1', name: '张三', college: '陶瓷美术学院', major: '陶艺', class_name: '陶艺1班'
    })).toMatchObject({ studentId: 's1', status: 'active', educationLevel: 'undergraduate' });

    expect(mapGradeTask({
      task_id: 'g1', course_name: '', teaching_class_name: '1班', teacher_name: '李老师', input_progress: 100,
      status: 'rejected', updated_at: 'now', reject_reason: '需修改'
    })).toMatchObject({ id: 'g1', courseName: '', rejectReason: '需修改' });

    expect(mapGradeTask({
      task_id: 'g2', course_name: '素描', teaching_class_name: '2班', teacher_name: '王老师', input_progress: 50,
      status: 'inputting', updated_at: 'later'
    })).not.toHaveProperty('rejectReason');
  });

  test('maps approvals, audit logs, and templates with defaults', () => {
    expect(mapApproval({
      approval_id: 'a1', biz_type: 'leave', applicant_name: '张三', applicant_id: 's1', title: '请假',
      status: 'pending', is_urgent: true, submitted_at: 'now'
    })).toEqual({
      id: 'a1', type: '请假', applicantName: '张三', applicantId: 's1', title: '请假', reason: '',
      status: 'pending', isUrgent: true, submittedAt: 'now'
    });

    expect(mapApproval({
      approval_id: 'a2', biz_type: 'feedback', applicant_name: '李四', applicant_id: 's2', title: '反馈',
      reason: '说明', status: 'done', is_urgent: false, submitted_at: 'later'
    }).type).toBe('feedback');

    expect(mapAuditLog({
      log_id: 'log1', action: 'create', action_type: 'notice', target: 'n1', created_at: 'now', result: 'success'
    })).toMatchObject({ id: 'log1', operatorName: '', operatorId: '', ip: '' });

    expect(mapAuditLog({
      log_id: 'log2', operator_name: '管理员', operator_id: 'a1', action: 'update', action_type: 'role',
      target: 'r1', created_at: 'later', result: 'success', ip: '127.0.0.1'
    })).toMatchObject({ operatorName: '管理员', operatorId: 'a1', ip: '127.0.0.1' });

    expect(mapTemplate({ template_id: 't1', name: '模板', question_count: 3, status: 'active' })).toEqual({
      id: 't1', name: '模板', description: '', questionCount: 3, status: 'active'
    });
  });
});
