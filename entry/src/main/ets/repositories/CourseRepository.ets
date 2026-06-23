// 课程、课表、选课

import { BaseRepository } from './BaseRepository';
import { Course, ScheduleItem, SelectionCourse, SelectionRoundInfo } from '../models/Course';
import { Notice } from '../models/Notice';
import { mockSchedule } from '../mock/mockCourses';
import { mockNotices } from '../mock/mockNotices';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { AppDatabase } from '../common/storage/AppDatabase';
import { SessionStorage } from '../common/storage/SessionStorage';
import { NoticeStore } from '../common/services/NoticeStore';
import { SelectionAdminRepository } from './SelectionAdminRepository';
import { AdminRepository } from './AdminRepository';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteRound, RemoteCourse } from '../common/remote/RemoteApi';
import { CourseLogic } from './CourseLogic';
import { TermUtils } from '../common/utils/TermUtils';

const CREDIT_LIMIT: number = 28; // 学分上限：选课事务据此校验，超出则拒绝
const KEY_SELECTED_IDS = 'local.selectedCourseIds.v1';
const KEY_IMPORTED_SCHEDULE = 'local.importedSchedule.v1';

export class CourseRepository extends BaseRepository {
  private static _instance?: CourseRepository;
  static get(): CourseRepository {
    if (!CourseRepository._instance) {
      CourseRepository._instance = new CourseRepository();
    }
    return CourseRepository._instance;
  }

  // 学生已选课程的 id 集合（管理端课程 id）。课程主数据全部来自管理端目录。
  private memberIds: string[] = [];
  private isMemberLoaded: boolean = false;
  // 导入课表：非空时覆盖 mockSchedule，作为 Schedule/Home/Today 的数据源。
  private importedSchedule: ScheduleItem[] = [];
  private isImportedLoaded: boolean = false;
  // 远程班级课表内存缓存（仅 useRemote 生效；拉取成功才置 loaded，失败下次重试）
  private remoteSchedule: ScheduleItem[] = [];
  private remoteScheduleLoaded: boolean = false;

  // ============ 已选成员关系（仅存 id，课程主数据以管理端为准） ============

  // RDB 就绪且已登录学生时，成员关系走 selections 表（按 studentId）；否则回退 Preferences 全局集合。
  private useRdbSelections(): boolean {
    return AppDatabase.isReady() && this.currentStudentId().length > 0;
  }

  private currentStudentId(): string {
    const student = SessionStorage.get().getStudent();
    return student ? student.studentId : '';
  }

  // 本地持久化 key 按当前登录学生隔离：base + '.' + studentId；未登录学生回退原 base。
  private scopedKey(base: string): string {
    const s = SessionStorage.get().getStudent();
    return (s && s.studentId.length > 0) ? `${base}.${s.studentId}` : base;
  }

  // ============ Track B 远程数据源（AppConfig.useRemote=true 且已登录时启用，读失败回退本地） ============

  private useRemote(): boolean {
    return AppConfig.useRemote && this.currentStudentId().length > 0;
  }

  private async remoteSelectionCourses(query?: string, category?: string): Promise<SelectionCourse[]> {
    // 开放课程与我的已选互不依赖：并行拉取（Promise.all 同时消费两个结果，省一个网络往返）
    const pair = await Promise.all([RemoteApi.listOpenCourses(), RemoteApi.mySelections(this.currentStudentId())]);
    const openRemote = pair[0];
    const mineRemote = pair[1];
    const mineIds: string[] = mineRemote.map((c) => c.id);
    const base: SelectionCourse[] = openRemote.map((r) => {
      const course = CourseLogic.toStudentCourse(CourseLogic.remoteToAdminCourse(r));
      const isSelected = mineIds.indexOf(course.id) >= 0;
      const sc: SelectionCourse = { course: course, status: isSelected ? 'selected' : 'available', conflictWith: undefined };
      return sc;
    });
    let items = CourseLogic.decorateStatuses(base);
    items = await this.decorateScheduleConflicts(items);
    if (query && query.length > 0) {
      const q = query.toLowerCase();
      items = items.filter((s) =>
        s.course.name.toLowerCase().includes(q) ||
        s.course.teacher.toLowerCase().includes(q) ||
        s.course.code.toLowerCase().includes(q));
    }
    if (category && category !== '全部') {
      items = items.filter((s) => s.course.category === category);
    }
    return this.delayCopy<SelectionCourse[]>(items);
  }

  private async remoteSelectionRound(): Promise<SelectionRoundInfo> {
    // 轮次与我的已选互不依赖：先同时发起，再依次消费（并行省一个网络往返）
    const roundPromise: Promise<RemoteRound | null> = RemoteApi.activeRound();
    const minePromise: Promise<RemoteCourse[]> = RemoteApi.mySelections(this.currentStudentId());
    const round = await roundPromise;
    const mineRemote = await minePromise;
    let selectedCredits = 0;
    mineRemote.forEach((c) => { selectedCredits += c.credit; });
    if (!round) {
      const closed: SelectionRoundInfo = {
        roundName: '当前无进行中的选课轮次',
        startTime: '—',
        endTime: '—',
        remainingSeconds: 0,
        selectedCredits: selectedCredits,
        creditLimit: CREDIT_LIMIT,
        inProgress: false
      };
      return this.delayCopy<SelectionRoundInfo>(closed);
    }
    const info: SelectionRoundInfo = {
      roundName: round.name,
      startTime: round.startTime,
      endTime: round.endTime,
      remainingSeconds: CourseLogic.computeRemainingSeconds(round.endTime),
      selectedCredits: selectedCredits,
      creditLimit: round.creditLimit,
      inProgress: true
    };
    return this.delayCopy<SelectionRoundInfo>(info);
  }

  private async getMemberIds(): Promise<string[]> {
    if (this.useRdbSelections()) {
      return this.loadMemberIdsFromRdb();
    }
    if (!this.isMemberLoaded) {
      const stored = await LocalDataStore.loadArray<string>(this.scopedKey(KEY_SELECTED_IDS), []);
      this.memberIds = stored.filter((id) => typeof id === 'string' && id.length > 0);
      this.isMemberLoaded = true;
    }
    return this.memberIds;
  }

  private async saveMemberIds(ids: string[]): Promise<void> {
    this.memberIds = ids;
    this.isMemberLoaded = true;
    await LocalDataStore.saveArray<string>(this.scopedKey(KEY_SELECTED_IDS), ids);
  }

  private async loadMemberIdsFromRdb(): Promise<string[]> {
    const resultSet = await AppDatabase.query(
      `SELECT course_id FROM selections WHERE student_id = ${AppDatabase.sqlText(this.currentStudentId())}`
    );
    const ids: string[] = [];
    try {
      const idx = resultSet.getColumnIndex('course_id');
      while (resultSet.goToNextRow()) {
        ids.push(resultSet.getString(idx));
      }
    } finally {
      resultSet.close();
    }
    return ids;
  }

  // 确保学生档案行存在（selections.student_id 外键），INSERT OR IGNORE 避免删除既有被引用行。
  private async ensureStudentProfile(): Promise<void> {
    const student = SessionStorage.get().getStudent();
    if (!student) {
      return;
    }
    await AppDatabase.execute(
      `INSERT OR IGNORE INTO student_profiles (student_id, name, college, major, class_name, grade, status, created_at, updated_at)
       VALUES (${AppDatabase.sqlText(student.studentId)}, ${AppDatabase.sqlText(student.name)}, ${AppDatabase.sqlText(student.college)}, ${AppDatabase.sqlText(student.major)}, ${AppDatabase.sqlText(student.className)}, ${AppDatabase.sqlText(student.grade)}, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`
    );
  }

  // 选课：RDB 模式插入 selections 行（round_id 置 NULL 规避轮次外键）；否则写 Preferences 集合。
  private async addMember(courseId: string): Promise<void> {
    if (this.useRdbSelections()) {
      await this.ensureStudentProfile();
      const sid = this.currentStudentId();
      await AppDatabase.execute(
        `INSERT OR IGNORE INTO selections (id, student_id, course_id, round_id, status, created_at)
         VALUES (${AppDatabase.sqlText('sel-' + sid + '-' + courseId)}, ${AppDatabase.sqlText(sid)}, ${AppDatabase.sqlText(courseId)}, NULL, 'selected', CURRENT_TIMESTAMP)`
      );
      return;
    }
    const ids = await this.getMemberIds();
    await this.saveMemberIds([courseId].concat(ids));
  }

  // 退课：RDB 模式删除 selections 行；否则从 Preferences 集合移除。
  private async removeMember(courseId: string): Promise<void> {
    if (this.useRdbSelections()) {
      await AppDatabase.execute(
        `DELETE FROM selections WHERE student_id = ${AppDatabase.sqlText(this.currentStudentId())} AND course_id = ${AppDatabase.sqlText(courseId)}`
      );
      return;
    }
    const ids = await this.getMemberIds();
    await this.saveMemberIds(ids.filter((id) => id !== courseId));
  }

  // ============ 管理端课程目录 → 学生课程映射（单一事实来源） ============

  // 学生可选目录：管理端 status='open' 的课程
  private async getOpenCatalog(): Promise<Course[]> {
    const adminCourses = await AdminRepository.get().getCourses();
    const open: Course[] = [];
    for (let i = 0; i < adminCourses.length; i++) {
      if (adminCourses[i].status === 'open') {
        open.push(CourseLogic.toStudentCourse(adminCourses[i]));
      }
    }
    return open;
  }

  // 完整目录（含已关闭）：用于「我的已选」与课程详情。
  // 联机模式走学生可访问的 /api/courses（此前误走管理端点，学生 token 403 后
  // 回退本地 mock，远程课程 id 查不到 → 详情页报「课程不存在」）。
  private async getFullCatalog(): Promise<Course[]> {
    if (this.useRemote()) {
      try {
        const remote = await RemoteApi.listAllCourses();
        return remote.map((r) => CourseLogic.toStudentCourse(CourseLogic.remoteToAdminCourse(r)));
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 远程失败回退本地目录
      }
    }
    const adminCourses = await AdminRepository.get().getCourses();
    return adminCourses.map((a) => CourseLogic.toStudentCourse(a));
  }

  // 当前生效课表，优先级：用户导入课表 > 远程班级课表（按名册班级匹配）> 内置 mockSchedule。
  // 远程结果成功后内存缓存；拉取失败不缓存（下次调用重试），当次回退本地。
  private async getActiveSchedule(): Promise<ScheduleItem[]> {
    if (!this.isImportedLoaded) {
      const stored = await LocalDataStore.loadArray<ScheduleItem>(this.scopedKey(KEY_IMPORTED_SCHEDULE), []);
      this.importedSchedule = stored.filter((s) => CourseLogic.isValidScheduleItem(s));
      this.isImportedLoaded = true;
    }
    if (this.importedSchedule.length > 0) {
      return this.importedSchedule;
    }
    if (this.useRemote()) {
      if (!this.remoteScheduleLoaded) {
        try {
          const remote = await RemoteApi.classSchedule();
          this.remoteSchedule = remote.items
            .map((r) => CourseLogic.remoteToScheduleItem(r))
            .filter((s) => CourseLogic.isValidScheduleItem(s));
          this.remoteScheduleLoaded = true;
        } catch (e) {
          // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
          if (!AppConfig.allowMockFallbackInRemote) {
            throw new Error('远程服务异常，请稍后重试');
          }
          // 远程不可用回退本地内置课表，与其余远程读分支的容错策略一致
        }
      }
      if (this.remoteScheduleLoaded && this.remoteSchedule.length > 0) {
        return this.remoteSchedule;
      }
    }
    return mockSchedule;
  }

  async saveImportedSchedule(items: ScheduleItem[]): Promise<number> {
    const valid = items.filter((s) => CourseLogic.isValidScheduleItem(s));
    this.importedSchedule = valid;
    this.isImportedLoaded = true;
    await LocalDataStore.saveArray<ScheduleItem>(this.scopedKey(KEY_IMPORTED_SCHEDULE), valid);
    return valid.length;
  }

  async clearImportedSchedule(): Promise<void> {
    this.importedSchedule = [];
    this.isImportedLoaded = true;
    await LocalDataStore.saveArray<ScheduleItem>(this.scopedKey(KEY_IMPORTED_SCHEDULE), []);
  }

  async hasImportedSchedule(): Promise<boolean> {
    await this.getActiveSchedule();
    return this.importedSchedule.length > 0;
  }

  // 与当前课表（导入课表/内置课表）冲突的可选课程标记为 conflict，
  // 与 decorateStatuses（已选课程之间的冲突）互补，避免选课中心放行与课表重叠的课。
  private async decorateScheduleConflicts(items: SelectionCourse[]): Promise<SelectionCourse[]> {
    const active = await this.getActiveSchedule();
    return items.map((item): SelectionCourse => {
      if (item.status !== 'available') {
        return item;
      }
      let hitName = '';
      for (let i = 0; i < active.length; i++) {
        if (CourseLogic.courseConflictsWithScheduleItem(item.course, active[i])) {
          hitName = active[i].courseName;
          break;
        }
      }
      if (hitName.length > 0) {
        const conf: SelectionCourse = { course: item.course, status: 'conflict', conflictWith: `与课表「${hitName}」时间冲突` };
        return conf;
      }
      return item;
    });
  }

  // 已选课程对应的课表行（并入「我的课表」）
  private async getSelectedScheduleItems(): Promise<ScheduleItem[]> {
    const mine = await this.getMySelectedCourses();
    const out: ScheduleItem[] = [];
    for (let i = 0; i < mine.length; i++) {
      const item = CourseLogic.selectedCourseToScheduleItem(mine[i].course);
      if (item !== undefined) {
        out.push(item);
      }
    }
    return out;
  }

  async getSchedule(term?: string, week?: number): Promise<ScheduleItem[]> {
    const active = await this.getActiveSchedule();
    // 已选课程并入课表，并置于前面：与导入课表同格冲突时优先显示学生本次已选课程
    const selected = await this.getSelectedScheduleItems();
    let items: ScheduleItem[] = selected.concat(active);
    if (term) {
      items = items.filter((s) => s.term === term);
    }
    if (week) {
      items = items.filter((s) => s.weeks.indexOf(week) >= 0);
    }
    return this.delayCopy<ScheduleItem[]>(items);
  }

  // 今日/明日课程：走 getSchedule 的合并结果（导入课表 + 已选课程）再按 weekday 过滤，
  // 与课表页“本周”同源。week 默认用按真实日期计算的当前教学周，与首页/课表页同口径。
  async getTodayCourses(weekday: number, week?: number): Promise<ScheduleItem[]> {
    const all = await this.getSchedule(undefined, week ?? TermUtils.teachingWeek());
    const items = all.filter((s) => s.weekday === weekday);
    return this.delayCopy<ScheduleItem[]>(items);
  }

  async getCourseDetail(courseId: string): Promise<Course> {
    // 课程详情以管理端目录为单一事实来源
    const catalog = await this.getFullCatalog();
    const found = catalog.find((c) => c.id === courseId);
    if (found) {
      return this.delayCopy<Course>(found);
    }
    // 导入课表的课程没有独立课程库记录：用课表行兜底构造详情（仅含课表中的真实字段）。
    const schedule = await this.getActiveSchedule();
    const matches = schedule.filter((s) => s.courseId === courseId);
    if (matches.length > 0) {
      const first = matches[0];
      const weekTexts = matches.map((s: ScheduleItem) => s.weekText);
      const derived: Course = {
        id: courseId,
        code: courseId,
        teachingClassNo: '—',
        name: first.courseName,
        category: first.courseType,
        credit: 0,
        teacher: first.teacher,
        college: first.campus ?? '—',
        campus: first.campus,
        classroom: first.classroom,
        weeks: weekTexts.join(' / '),
        periodStart: first.periodStart,
        periodEnd: first.periodEnd,
        weekday: first.weekday,
        description: `本课程信息来自导入课表（${first.term}）。上课时间：周${first.weekday} 第 ${first.periodStart}-${first.periodEnd} 节。`
      };
      return this.delayCopy<Course>(derived);
    }
    return this.reject('课程不存在', 'notFound');
  }

  // ============ 选课事务（轮次 / 容量 / 学分 / 冲突 校验） ============

  // 选课轮次：与管理端「进行中」轮次共享同一事实来源
  async getSelectionRound(): Promise<SelectionRoundInfo> {
    if (this.useRemote()) {
      try {
        return await this.remoteSelectionRound();
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    const active = await SelectionAdminRepository.get().getActiveRound();
    const catalog = await this.getFullCatalog();
    const memberIds = await this.getMemberIds();
    let selectedCredits = 0;
    for (let i = 0; i < catalog.length; i++) {
      if (memberIds.indexOf(catalog[i].id) >= 0) {
        selectedCredits += catalog[i].credit;
      }
    }
    if (!active) {
      const closed: SelectionRoundInfo = {
        roundName: '当前无进行中的选课轮次',
        startTime: '—',
        endTime: '—',
        remainingSeconds: 0,
        selectedCredits: selectedCredits,
        creditLimit: CREDIT_LIMIT,
        inProgress: false
      };
      return this.delayCopy<SelectionRoundInfo>(closed);
    }
    const info: SelectionRoundInfo = {
      roundName: active.name,
      startTime: active.startTime,
      endTime: active.endTime,
      remainingSeconds: CourseLogic.computeRemainingSeconds(active.endTime),
      selectedCredits: selectedCredits,
      creditLimit: CREDIT_LIMIT,
      inProgress: true
    };
    return this.delayCopy<SelectionRoundInfo>(info);
  }

  async getSelectionCourses(query?: string, category?: string): Promise<SelectionCourse[]> {
    if (this.useRemote()) {
      try {
        return await this.remoteSelectionCourses(query, category);
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    const catalog = await this.getOpenCatalog();
    const memberIds = await this.getMemberIds();
    const base: SelectionCourse[] = catalog.map((c) => {
      const isSelected = memberIds.indexOf(c.id) >= 0;
      const sc: SelectionCourse = { course: c, status: isSelected ? 'selected' : 'available', conflictWith: undefined };
      return sc;
    });
    let items = CourseLogic.decorateStatuses(base);
    items = await this.decorateScheduleConflicts(items);
    if (query && query.length > 0) {
      const q = query.toLowerCase();
      items = items.filter((s) =>
        s.course.name.toLowerCase().includes(q) ||
        s.course.teacher.toLowerCase().includes(q) ||
        s.course.code.toLowerCase().includes(q)
      );
    }
    if (category && category !== '全部') {
      items = items.filter((s) => s.course.category === category);
    }
    return this.delayCopy<SelectionCourse[]>(items);
  }

  async selectCourse(courseId: string): Promise<boolean> {
    if (this.useRemote()) {
      try {
        await RemoteApi.select(this.currentStudentId(), courseId);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    // 轮次门禁：管理端无进行中轮次时不能选课
    const active = await SelectionAdminRepository.get().getActiveRound();
    if (!active) {
      return this.reject('当前不在选课时间，暂不能选课');
    }
    const catalog = await this.getOpenCatalog();
    const target = catalog.find((c) => c.id === courseId);
    if (!target) {
      return this.reject('课程不存在或未开放选课', 'notFound');
    }
    const memberIds = await this.getMemberIds();
    if (memberIds.indexOf(courseId) >= 0) {
      return this.reject('已选该课程');
    }
    // 注：旧「限选一门」规则已移除（与后端同步）；多选由学分上限 + 时间冲突兜底。
    const cap = target.capacity;
    const cnt = target.selectedCount;
    if (cap !== undefined && cnt !== undefined && cnt >= cap) {
      return this.reject('课程容量已满');
    }
    // 学分上限与时间冲突：基于当前已选课程
    const selected: Course[] = [];
    let selectedCredits = 0;
    for (let i = 0; i < catalog.length; i++) {
      if (memberIds.indexOf(catalog[i].id) >= 0) {
        selected.push(catalog[i]);
        selectedCredits += catalog[i].credit;
      }
    }
    if (selectedCredits + target.credit > CREDIT_LIMIT) {
      return this.reject(`超过学分上限（${CREDIT_LIMIT} 学分）`);
    }
    for (let i = 0; i < selected.length; i++) {
      if (CourseLogic.coursesConflict(target, selected[i])) {
        return this.reject(`与「${selected[i].name}」时间冲突`);
      }
    }
    // 与当前课表（导入课表/内置课表）冲突校验：避免选到与既有课程时间重叠的课
    const activeSchedule = await this.getActiveSchedule();
    for (let i = 0; i < activeSchedule.length; i++) {
      if (CourseLogic.courseConflictsWithScheduleItem(target, activeSchedule[i])) {
        return this.reject(`与课表「${activeSchedule[i].courseName}」时间冲突`);
      }
    }
    await this.addMember(courseId);
    // 选课人数回写管理端单一事实来源
    await AdminRepository.get().adjustEnrollment(target.code, 1);
    return this.delay<boolean>(true);
  }

  async dropCourse(courseId: string): Promise<boolean> {
    if (this.useRemote()) {
      try {
        await RemoteApi.drop(this.currentStudentId(), courseId);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const memberIds = await this.getMemberIds();
    if (memberIds.indexOf(courseId) < 0) {
      return this.reject('该课程未被选中');
    }
    await this.removeMember(courseId);
    // 退课：名额回退到管理端单一事实来源
    const catalog = await this.getFullCatalog();
    const target = catalog.find((c) => c.id === courseId);
    if (target) {
      await AdminRepository.get().adjustEnrollment(target.code, -1);
    }
    return this.delay<boolean>(true);
  }

  async getMySelectedCourses(): Promise<SelectionCourse[]> {
    if (this.useRemote()) {
      try {
        const mineRemote = await RemoteApi.mySelections(this.currentStudentId());
        const remoteItems: SelectionCourse[] = mineRemote.map((r) => {
          const sc: SelectionCourse = { course: CourseLogic.toStudentCourse(CourseLogic.remoteToAdminCourse(r)), status: 'selected', conflictWith: undefined };
          return sc;
        });
        return this.delayCopy<SelectionCourse[]>(remoteItems);
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    const catalog = await this.getFullCatalog();
    const memberIds = await this.getMemberIds();
    const items: SelectionCourse[] = [];
    for (let i = 0; i < catalog.length; i++) {
      if (memberIds.indexOf(catalog[i].id) >= 0) {
        const sc: SelectionCourse = { course: catalog[i], status: 'selected', conflictWith: undefined };
        items.push(sc);
      }
    }
    return this.delayCopy<SelectionCourse[]>(items);
  }

  // 通知
  async getNotices(category?: string): Promise<Notice[]> {
    if (this.useRemote()) {
      try {
        const remote = await RemoteApi.listNotices(this.currentStudentId(), category);
        const remoteItems: Notice[] = remote.map((n) => CourseLogic.remoteToNotice(n));
        return this.delayCopy<Notice[]>(remoteItems);
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    let items = await NoticeStore.list(mockNotices, category);
    if (category && category !== '全部') {
      items = items.filter((n) => n.category === category);
    }
    return this.delayCopy<Notice[]>(items);
  }

  async getNoticeDetail(id: string): Promise<Notice> {
    if (this.useRemote()) {
      try {
        const remote = await RemoteApi.noticeDetail(this.currentStudentId(), id);
        return this.delayCopy<Notice>(CourseLogic.remoteToNotice(remote));
      } catch (e) {
        // 远程失败：remote 模式禁止静默回退时直接抛错，交由页面错误态呈现
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('远程服务异常，请稍后重试');
        }
        // 否则回退本地
      }
    }
    const item = await NoticeStore.detail(mockNotices, id);
    if (!item) {
      return this.reject('通知不存在', 'notFound');
    }
    return this.delayCopy<Notice>(item);
  }

  async markNoticeRead(id: string): Promise<boolean> {
    if (this.useRemote()) {
      try {
        await RemoteApi.markNoticeRead(this.currentStudentId(), id);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    await NoticeStore.markRead(id);
    return this.delay<boolean>(true);
  }
}
