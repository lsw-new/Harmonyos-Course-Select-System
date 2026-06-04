import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { LocalDataStore } from '../main/ets/common/storage/LocalDataStore';
import { AdminRepository } from '../main/ets/repositories/AdminRepository';
import { CourseRepository } from '../main/ets/repositories/CourseRepository';
import { ProfileRepository } from '../main/ets/repositories/ProfileRepository';
import { StudentAdminRepository } from '../main/ets/repositories/StudentAdminRepository';
import { mockAdminProfile } from '../main/ets/mock/mockAdmin';
import { mockStudentProfile } from '../main/ets/mock/mockUser';
import { SessionStorage } from '../main/ets/common/storage/SessionStorage';
import { PreferenceStorage } from '../main/ets/common/storage/PreferenceStorage';
import { AppDatabase } from '../main/ets/common/storage/AppDatabase';
import { DATABASE_NAME, DATABASE_SCHEMA_SQL, DATABASE_VERSION } from '../main/ets/common/storage/DatabaseSchema';
import { AdminCourseWritePayload, GradeAuditItem, NoticeDraft } from '../main/ets/models/Admin';
import { LeaveRequest } from '../main/ets/models/Misc';
import { FileService } from '../main/ets/common/services/FileService';
import { ScheduleImportService } from '../main/ets/common/services/ScheduleImportService';
import { ScheduleItem } from '../main/ets/models/Course';

async function clearLocalUnitState(): Promise<void> {
  await SessionStorage.get().clear();
  await PreferenceStorage.get().remove('local.adminApprovals.v1');
  await PreferenceStorage.get().remove('local.adminGrades.v1');
  await PreferenceStorage.get().remove('local.adminCourses.v1');
  await PreferenceStorage.get().remove('local.leaveRequests.v1');
  await PreferenceStorage.get().remove('local.notices.v1');
  await PreferenceStorage.get().remove('local.noticeReads.v1');
  await PreferenceStorage.get().remove('local.downloadHistory.v1');
}

function buildCoursePayload(code: string, selectedCount: number, capacity: number): AdminCourseWritePayload {
  const payload: AdminCourseWritePayload = {
    code: code,
    name: `单测课程 ${code}`,
    teacher: `单测教师 ${code}`,
    category: 'elective',
    credit: 2,
    timeText: `周五 ${code} 节`,
    capacity: capacity,
    selectedCount: selectedCount,
    status: 'draft'
  };
  return payload;
}

async function captureErrorMessage(action: () => Promise<void>): Promise<string> {
  try {
    await action();
  } catch (e) {
    const error = e as Error;
    if (error.message !== undefined) {
      return error.message;
    }
    return `${e}`;
  }
  return '';
}

export default function localUnitTest() {
  describe('localUnitTest', () => {
    beforeAll(() => {
    });
    beforeEach(async () => {
      await clearLocalUnitState();
    });
    afterEach(async () => {
      await clearLocalUnitState();
    });
    afterAll(() => {
    });

    it('scheduleImportServiceParsesGridWeeksAndOfferings', 0, () => {
      const ss = '<?xml version="1.0"?><sst><si><t>软件工程 (VDZ02102903.09) (黄卫东) \n(3-11单,12 上茶苑教8栋512)</t></si>' +
        '<si><t>中国近现代史纲要 (VMK01100203.43) (谢双明) \n(2-9 实践考察) \n鸿蒙移动应用开发综合实践 (VDZ02119303.10) (王鑫) \n(13-15 上茶苑教9栋401)</t></si></sst>';
      const sheet = '<worksheet><sheetData>' +
        '<row r="5"><c r="B5" t="s"><v>0</v></c></row>' +
        '<row r="9"><c r="C9" t="s"><v>1</v></c></row>' +
        '</sheetData><mergeCells count="2"><mergeCell ref="B5:B6"/><mergeCell ref="C9:C12"/></mergeCells></worksheet>';
      const items = ScheduleImportService.parseSchedule(ss, sheet, '2025-2026-2');
      expect(items.length).assertEqual(3);

      const eng = items.find((s: ScheduleItem) => s.courseName === '软件工程');
      expect(eng !== undefined).assertTrue();
      if (eng !== undefined) {
        expect(eng.weekday).assertEqual(1);
        expect(eng.periodStart).assertEqual(1);
        expect(eng.periodEnd).assertEqual(2);
        expect(eng.startTime).assertEqual('08:00');
        expect(eng.endTime).assertEqual('09:35');
        expect(eng.courseType).assertEqual('必修');
        expect(eng.weeks.join(',')).assertEqual('3,5,7,9,11,12');
      }

      const hist = items.find((s: ScheduleItem) => s.courseName === '中国近现代史纲要');
      expect(hist !== undefined).assertTrue();
      if (hist !== undefined) {
        expect(hist.weekday).assertEqual(2);
        expect(hist.periodStart).assertEqual(5);
        expect(hist.periodEnd).assertEqual(8);
        expect(hist.courseType).assertEqual('公选');
        expect(hist.classroom).assertEqual('实践考察');
        expect(hist.weeks.length).assertEqual(8);
      }

      const prac = items.find((s: ScheduleItem) => s.courseName === '鸿蒙移动应用开发综合实践');
      expect(prac !== undefined).assertTrue();
      if (prac !== undefined) {
        expect(prac.type).assertEqual('practice');
        expect(prac.weeks.join(',')).assertEqual('13,14,15');
      }
    });

    it('scheduleImportServiceExpandsOddEvenWeeks', 0, () => {
      expect(ScheduleImportService.expandWeeks('2-10双,17').join(',')).assertEqual('2,4,6,8,10,17');
      expect(ScheduleImportService.expandWeeks('3-11单').join(',')).assertEqual('3,5,7,9,11');
      expect(ScheduleImportService.expandWeeks('2-5,7-9').join(',')).assertEqual('2,3,4,5,7,8,9');
    });

    it('localDataStoreReturnsFallbackWhenPreferencesAreUnavailable', 0, async () => {
      const fallback: string[] = ['mock'];
      const result = await LocalDataStore.loadArray<string>('test.unavailable', fallback);
      expect(result.length).assertEqual(1);
      expect(result[0]).assertEqual('mock');
    });

    it('databaseSchemaDefinesCoreBusinessTables', 0, () => {
      const schemaText = DATABASE_SCHEMA_SQL.join('\n');
      expect(DATABASE_NAME).assertEqual('dtest2_app.db');
      expect(DATABASE_VERSION).assertEqual(2);
      expect(DATABASE_VERSION >= 1).assertTrue();
      expect(schemaText).assertContain('CREATE TABLE IF NOT EXISTS notices');
      expect(schemaText).assertContain('CREATE TABLE IF NOT EXISTS notice_reads');
      expect(schemaText).assertContain('CREATE TABLE IF NOT EXISTS leave_requests');
      expect(schemaText).assertContain('CREATE TABLE IF NOT EXISTS approval_instances');
      expect(schemaText).assertContain('CREATE TABLE IF NOT EXISTS courses');
      expect(schemaText).assertContain('CREATE TABLE IF NOT EXISTS grades');
      expect(AppDatabase.sqlText("a'b")).assertEqual("'a''b'");
    });

    it('fileServiceReturnsStableMockPathAndRejectsUnsafeFileNames', 0, async () => {
      const savedPath = await FileService.downloadFile('mock://files/calendar.pdf', '校历.pdf');
      expect(savedPath).assertEqual('mock://downloads/%E6%A0%A1%E5%8E%86.pdf');

      const traversalError = await captureErrorMessage(async () => {
        await FileService.downloadFile('mock://files/calendar.pdf', '../secret.pdf');
      });
      expect(traversalError).assertContain('文件名不能包含路径');

      const controlError = await captureErrorMessage(async () => {
        await FileService.downloadFile('mock://files/calendar.pdf', 'bad\nname.pdf');
      });
      expect(controlError).assertContain('非法字符');
    });

    it('fileServiceRejectsEmptyUrlUnsupportedProtocolAndPathSeparators', 0, async () => {
      const emptyUrlError = await captureErrorMessage(async () => {
        await FileService.downloadFile('', 'safe.pdf');
      });
      expect(emptyUrlError).assertContain('下载地址不能为空');

      const unsupportedProtocolError = await captureErrorMessage(async () => {
        await FileService.downloadFile('ftp://files/calendar.pdf', 'safe.pdf');
      });
      expect(unsupportedProtocolError).assertContain('不支持');

      const slashError = await captureErrorMessage(async () => {
        await FileService.downloadFile('mock://files/calendar.pdf', 'folder/safe.pdf');
      });
      expect(slashError).assertContain('文件名不能包含路径');

      const backslashError = await captureErrorMessage(async () => {
        await FileService.downloadFile('mock://files/calendar.pdf', 'folder\\safe.pdf');
      });
      expect(backslashError).assertContain('文件名不能包含路径');
    });

    it('sessionStorageAuthenticatesAdminSessionAndClearsSession', 0, async () => {
      const session = SessionStorage.get();
      await session.clear();

      await session.setAdminSession('unit-admin-token', mockAdminProfile);
      expect(session.isAuthenticated()).assertTrue();

      await session.clear();
      expect(session.isAuthenticated()).assertFalse();
    });

    it('adminCourseRepositoryCreatesCourseAndFindsItInCourses', 0, async () => {
      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const repo = new AdminRepository();
      const payload = buildCoursePayload('UT-COURSE-1', 0, 30);

      const created = await repo.createCourse(payload);
      expect(created.code).assertEqual('UT-COURSE-1');
      expect(created.selectedCount).assertEqual(0);

      const courses = await repo.getCourses('UT-COURSE-1');
      expect(courses.some((item) => item.code === 'UT-COURSE-1')).assertTrue();
    });

    it('adminCourseRepositoryRejectsDuplicateCourseCode', 0, async () => {
      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const repo = new AdminRepository();

      const duplicateError = await captureErrorMessage(async () => {
        await repo.createCourse(buildCoursePayload('CS101', 0, 30));
      });
      expect(duplicateError).assertContain('课程代码已存在');
    });

    it('adminCourseRepositoryRejectsInvalidSelectedCountAndCapacity', 0, async () => {
      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const repo = new AdminRepository();

      const selectedOverCapacityError = await captureErrorMessage(async () => {
        await repo.createCourse(buildCoursePayload('UT-INVALID-1', 11, 10));
      });
      expect(selectedOverCapacityError).assertContain('已选人数');

      const infiniteCapacityError = await captureErrorMessage(async () => {
        await repo.createCourse(buildCoursePayload('UT-INVALID-2', 0, Infinity));
      });
      expect(infiniteCapacityError).assertContain('容量');

      const decimalCapacityError = await captureErrorMessage(async () => {
        await repo.createCourse(buildCoursePayload('UT-INVALID-3', 0, 12.5));
      });
      expect(decimalCapacityError).assertContain('容量');
    });

    it('adminCourseRepositoryRejectsDeleteWhenCourseHasSelectedStudents', 0, async () => {
      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const repo = new AdminRepository();
      const created = await repo.createCourse(buildCoursePayload('UT-DELETE-BLOCKED', 1, 30));

      const deleteError = await captureErrorMessage(async () => {
        await repo.deleteCourse(created.id);
      });
      expect(deleteError).assertContain('已有学生选课');
    });

    it('adminCourseRepositoryDeletesCourseWhenSelectedCountIsZero', 0, async () => {
      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const repo = new AdminRepository();
      const created = await repo.createCourse(buildCoursePayload('UT-DELETE-OK', 0, 30));

      const deleted = await repo.deleteCourse(created.id);
      expect(deleted).assertTrue();

      const courses = await repo.getCourses('UT-DELETE-OK');
      expect(courses.some((item) => item.id === created.id)).assertFalse();
    });

    it('adminRepositoryRejectsCourseCreateAndGradeRejectWithoutAdminSession', 0, async () => {
      const repo = new AdminRepository();
      const createError = await captureErrorMessage(async () => {
        await repo.createCourse(buildCoursePayload('UT-NO-AUTH', 0, 30));
      });
      expect(createError).assertContain('无权限');

      const rejectGradeError = await captureErrorMessage(async () => {
        await repo.rejectGrade({ id: 'ga-1', reason: '无权限单测' });
      });
      expect(rejectGradeError).assertContain('无权限');
      const updateStudentError = await captureErrorMessage(async () => {
        await StudentAdminRepository.get().updateStatus('2023307020941', 'suspended');
      });
      expect(updateStudentError).assertContain('\u65e0\u6743\u9650');
    });

    it('adminGradeInputRejectApproveFlowTransitionsStatus', 0, async () => {
      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const repo = new AdminRepository();

      const inputting = await repo.inputGrade({ id: 'ga-2', inputProgress: 100 });
      expect(inputting.status).assertEqual('pendingAudit');
      expect(inputting.inputProgress).assertEqual(100);

      const reason = '分数构成缺少平时成绩，请补录';
      const rejected = await repo.rejectGrade({ id: 'ga-2', reason: reason });
      expect(rejected).assertTrue();
      const afterReject = await repo.getGradeAudits('rejected');
      const rejectedItem = afterReject.find((item: GradeAuditItem) => item.id === 'ga-2');
      expect(rejectedItem !== undefined).assertTrue();
      if (rejectedItem !== undefined) {
        expect(rejectedItem.inputProgress).assertEqual(100);
        expect(rejectedItem.rejectReason).assertEqual(reason);
      }

      const reinput = await repo.inputGrade({ id: 'ga-2', inputProgress: 99 });
      expect(reinput.status).assertEqual('inputting');
      expect(reinput.rejectReason === undefined).assertTrue();
      const pending = await repo.inputGrade({ id: 'ga-2', inputProgress: 100 });
      expect(pending.status).assertEqual('pendingAudit');
      expect(pending.rejectReason === undefined).assertTrue();

      const approved = await repo.approveGrade('ga-2');
      expect(approved).assertTrue();
      const published = await repo.getGradeAudits('published');
      expect(published.some((item: GradeAuditItem) => item.id === 'ga-2' && item.rejectReason === undefined)).assertTrue();
    });

    it('adminNoticePublishPersistsToStudentNoticeList', 0, async () => {
      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const title = `UT Notice ${Date.now()}`;
      const draft: NoticeDraft = {
        title: title,
        content: 'Unit test notice content',
        publisher: mockAdminProfile.name,
        category: 'unit',
        urgency: 'normal',
        receiverType: 'students',
        receiverScope: []
      };

      const published = await AdminRepository.get().publishNotice(draft);
      expect(published).assertTrue();

      await SessionStorage.get().setStudentSession('unit-student-token', mockStudentProfile);
      const notices = await CourseRepository.get().getNotices();
      const item = notices.find((notice) => notice.title === title);
      expect(item !== undefined).assertTrue();
      if (item !== undefined) {
        expect(item.isRead).assertFalse();
        await CourseRepository.get().markNoticeRead(item.id);
        const detail = await CourseRepository.get().getNoticeDetail(item.id);
        expect(detail.isRead).assertTrue();
      }
    });

    it('studentLeaveCreatesAdminApprovalAndApprovalUpdatesLeaveState', 0, async () => {
      await SessionStorage.get().setStudentSession('unit-student-token', mockStudentProfile);
      const reason = `UT leave reason ${Date.now()}`;
      const leave = await ProfileRepository.get().submitLeave({
        type: 'personal',
        startDate: '2026-06-01',
        endDate: '2026-06-02',
        reason: reason,
        attachments: []
      });

      await SessionStorage.get().setAdminSession('unit-admin-token', mockAdminProfile);
      const approvalId = `ap-${leave.id}`;
      const approvals = await AdminRepository.get().getApprovals('pending');
      expect(approvals.some((item) => item.id === approvalId && item.reason === reason)).assertTrue();

      const comment = 'Unit test approval comment';
      const approved = await AdminRepository.get().approve(approvalId, comment);
      expect(approved).assertTrue();

      await SessionStorage.get().setStudentSession('unit-student-token', mockStudentProfile);
      const leaves = await ProfileRepository.get().getLeaveRequests();
      const updated = leaves.find((item: LeaveRequest) => item.id === leave.id);
      expect(updated !== undefined).assertTrue();
      if (updated !== undefined) {
        expect(updated.state).assertEqual('approved');
        expect(updated.feedback).assertEqual(comment);
      }
    });
  });
}
