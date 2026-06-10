// 管理端本地 RDB（AppDatabase/SQLite）直接读写层：成绩任务、课程目录、审批实例的
// SQL 持久化。仅依赖静态 AppDatabase 与数据类型/种子数据，无会话/网络/实例状态。
// 从 AdminRepository 平移（行为不变）：AdminRepository 退化为 RdbStore + RemoteApi + Preferences 的编排者。

import {
  AdminCourseItem, AdminCourseCategory, AdminCourseStatus,
  GradeAuditItem, GradeAuditStatus, ApprovalItem, ApprovalStatus
} from '../models/Admin';
import { mockAdminCourses } from '../mock/mockAdmin';
import { AppDatabase } from '../common/storage/AppDatabase';

// v2：内置课程排课时间改到晚间 9-10 节（避免与真实课表冲突），升版本让已种子的设备按新时间重新 UPSERT。
const SEED_COURSES_FLAG = 'seed.courses.v2';

export class AdminRdbStore {
  // 从 grade_tasks 表加载成绩审核任务列表
  static async loadGradeTasksFromRdb(): Promise<GradeAuditItem[]> {
    const resultSet = await AppDatabase.query(
      `SELECT
         gt.task_id,
         COALESCE(c.name, '') AS course_name,
         COALESCE(gt.teaching_class_name, '') AS teaching_class_name,
         COALESCE(gt.teacher_name, '') AS teacher_name,
         gt.input_progress,
         gt.status,
         gt.updated_at,
         COALESCE(gt.reject_reason, '') AS reject_reason
       FROM grade_tasks gt
       LEFT JOIN courses c ON c.course_id = gt.course_id
       ORDER BY gt.updated_at DESC`
    );
    const items: GradeAuditItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const status = resultSet.getString(resultSet.getColumnIndex('status')) as GradeAuditStatus;
        const rejectReason = resultSet.getString(resultSet.getColumnIndex('reject_reason'));
        const item: GradeAuditItem = {
          id: resultSet.getString(resultSet.getColumnIndex('task_id')),
          courseName: resultSet.getString(resultSet.getColumnIndex('course_name')),
          teachingClassName: resultSet.getString(resultSet.getColumnIndex('teaching_class_name')),
          teacherName: resultSet.getString(resultSet.getColumnIndex('teacher_name')),
          inputProgress: resultSet.getLong(resultSet.getColumnIndex('input_progress')),
          status: status,
          updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at'))
        };
        if (status === 'rejected' && rejectReason.length > 0) {
          item.rejectReason = rejectReason;
        }
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  // approve 时：若 RDB 就绪，尝试批量将该任务关联课程的所有选课学生的成绩行置为 published
  static async publishGradesToRdb(taskId: string): Promise<void> {
    // 1. 从 grade_tasks 找 course_id
    const taskResultSet = await AppDatabase.query(
      `SELECT course_id FROM grade_tasks WHERE task_id = ${AppDatabase.sqlText(taskId)} LIMIT 1`
    );
    let courseId = '';
    try {
      if (taskResultSet.goToNextRow()) {
        courseId = taskResultSet.getString(taskResultSet.getColumnIndex('course_id'));
      }
    } finally {
      taskResultSet.close();
    }
    if (courseId.length === 0) {
      // grade_tasks 中无此任务或无 course_id，跳过 grades 写入
      return;
    }
    // 2. 更新 grade_tasks 状态
    await AppDatabase.execute(
      `UPDATE grade_tasks SET status = 'published', updated_at = CURRENT_TIMESTAMP WHERE task_id = ${AppDatabase.sqlText(taskId)}`
    );
    // 3. 将该课程下所有 grades 行置为 published（若存在）
    await AppDatabase.execute(
      `UPDATE grades SET status = 'published', published_at = CURRENT_TIMESTAMP WHERE course_id = ${AppDatabase.sqlText(courseId)} AND status != 'published'`
    );
  }

  // 更新 grade_tasks 表状态（用于 inputGrade / rejectGrade）
  static async updateGradeTaskStatusInRdb(taskId: string, status: string, rejectReason?: string): Promise<void> {
    const taskResultSet = await AppDatabase.query(
      `SELECT task_id FROM grade_tasks WHERE task_id = ${AppDatabase.sqlText(taskId)} LIMIT 1`
    );
    let exists = false;
    try {
      exists = taskResultSet.goToNextRow();
    } finally {
      taskResultSet.close();
    }
    if (!exists) {
      return;
    }
    const reasonSql = rejectReason !== undefined
      ? `, reject_reason = ${AppDatabase.sqlText(rejectReason)}`
      : '';
    await AppDatabase.execute(
      `UPDATE grade_tasks SET status = ${AppDatabase.sqlText(status)}, updated_at = CURRENT_TIMESTAMP${reasonSql} WHERE task_id = ${AppDatabase.sqlText(taskId)}`
    );
  }

  // 首次进入 RDB 模式时把内置课程灌入 courses 表，并用 app_meta 标记，避免删空后又被重新种子。
  static async seedCoursesIfNeeded(): Promise<void> {
    const resultSet = await AppDatabase.query(
      `SELECT value FROM app_meta WHERE key = ${AppDatabase.sqlText(SEED_COURSES_FLAG)} LIMIT 1`
    );
    let seeded = false;
    try {
      seeded = resultSet.goToNextRow();
    } finally {
      resultSet.close();
    }
    if (seeded) {
      return;
    }
    const seed = JSON.parse(JSON.stringify(mockAdminCourses)) as AdminCourseItem[];
    for (let i = 0; i < seed.length; i++) {
      await AdminRdbStore.upsertCourseToRdb(seed[i]);
    }
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO app_meta (key, value, updated_at) VALUES (${AppDatabase.sqlText(SEED_COURSES_FLAG)}, '1', CURRENT_TIMESTAMP)`
    );
  }

  static async loadCoursesFromRdb(): Promise<AdminCourseItem[]> {
    const resultSet = await AppDatabase.query(
      `SELECT course_id, code, name, teacher, category, credit, COALESCE(time_text, '') AS time_text, capacity, selected_count, status
       FROM courses ORDER BY created_at DESC`
    );
    const items: AdminCourseItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const item: AdminCourseItem = {
          id: resultSet.getString(resultSet.getColumnIndex('course_id')),
          code: resultSet.getString(resultSet.getColumnIndex('code')),
          name: resultSet.getString(resultSet.getColumnIndex('name')),
          teacher: resultSet.getString(resultSet.getColumnIndex('teacher')),
          category: resultSet.getString(resultSet.getColumnIndex('category')) as AdminCourseCategory,
          credit: resultSet.getDouble(resultSet.getColumnIndex('credit')),
          timeText: resultSet.getString(resultSet.getColumnIndex('time_text')),
          capacity: resultSet.getLong(resultSet.getColumnIndex('capacity')),
          selectedCount: resultSet.getLong(resultSet.getColumnIndex('selected_count')),
          status: resultSet.getString(resultSet.getColumnIndex('status')) as AdminCourseStatus
        };
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  static async upsertCourseToRdb(item: AdminCourseItem): Promise<void> {
    await AppDatabase.execute(
      `INSERT INTO courses (course_id, code, name, category, credit, teacher, capacity, selected_count, time_text, status, updated_at)
       VALUES (${AppDatabase.sqlText(item.id)}, ${AppDatabase.sqlText(item.code)}, ${AppDatabase.sqlText(item.name)}, ${AppDatabase.sqlText(item.category)}, ${item.credit}, ${AppDatabase.sqlText(item.teacher)}, ${item.capacity}, ${item.selectedCount}, ${AppDatabase.sqlText(item.timeText)}, ${AppDatabase.sqlText(item.status)}, CURRENT_TIMESTAMP)
       ON CONFLICT(course_id) DO UPDATE SET
         code = excluded.code, name = excluded.name, category = excluded.category, credit = excluded.credit,
         teacher = excluded.teacher, capacity = excluded.capacity, selected_count = excluded.selected_count,
         time_text = excluded.time_text, status = excluded.status, updated_at = CURRENT_TIMESTAMP`
    );
  }

  // 全量写回：逐条 UPSERT（按 course_id 原地更新，不触发 selections 外键删除），再删除 next 中不存在的课程（被删课程已校验无人选）。
  static async saveCoursesToRdb(next: AdminCourseItem[]): Promise<void> {
    for (let i = 0; i < next.length; i++) {
      await AdminRdbStore.upsertCourseToRdb(next[i]);
    }
    if (next.length > 0) {
      const keepIds = next.map((c) => AppDatabase.sqlText(c.id)).join(', ');
      await AppDatabase.execute(`DELETE FROM courses WHERE course_id NOT IN (${keepIds})`);
    } else {
      await AppDatabase.execute('DELETE FROM courses');
    }
  }

  static async getApprovalItemsFromRdb(): Promise<ApprovalItem[]> {
    const resultSet = await AppDatabase.query(
      `SELECT
        ai.approval_id,
        ai.biz_type,
        COALESCE(sp.name, ai.applicant_id, '') AS applicant_name,
        COALESCE(ai.applicant_id, '') AS applicant_id,
        ai.title,
        COALESCE(ai.reason, '') AS reason,
        ai.status,
        CASE WHEN ai.is_urgent = 1 THEN 'true' ELSE 'false' END AS is_urgent,
        ai.submitted_at
       FROM approval_instances ai
       LEFT JOIN student_profiles sp ON sp.student_id = ai.applicant_id
       ORDER BY ai.submitted_at DESC`
    );
    const items: ApprovalItem[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const item: ApprovalItem = {
          id: resultSet.getString(resultSet.getColumnIndex('approval_id')),
          type: resultSet.getString(resultSet.getColumnIndex('biz_type')) === 'leave' ? '请假' : resultSet.getString(resultSet.getColumnIndex('biz_type')),
          applicantName: resultSet.getString(resultSet.getColumnIndex('applicant_name')),
          applicantId: resultSet.getString(resultSet.getColumnIndex('applicant_id')),
          title: resultSet.getString(resultSet.getColumnIndex('title')),
          reason: resultSet.getString(resultSet.getColumnIndex('reason')),
          status: resultSet.getString(resultSet.getColumnIndex('status')) as ApprovalStatus,
          isUrgent: resultSet.getString(resultSet.getColumnIndex('is_urgent')) === 'true',
          submittedAt: resultSet.getString(resultSet.getColumnIndex('submitted_at'))
        };
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  static async saveApprovalStatusToRdb(id: string, status: ApprovalStatus, comment: string): Promise<void> {
    await AppDatabase.execute(
      `UPDATE approval_instances
       SET status = ${AppDatabase.sqlText(status)}, updated_at = CURRENT_TIMESTAMP
       WHERE approval_id = ${AppDatabase.sqlText(id)}`
    );
    await AppDatabase.execute(
      `UPDATE approval_steps
       SET status = ${AppDatabase.sqlText(status)}, comment = ${AppDatabase.sqlText(comment)}, handled_at = CURRENT_TIMESTAMP
       WHERE approval_id = ${AppDatabase.sqlText(id)} AND step_order = 1`
    );
  }
}
