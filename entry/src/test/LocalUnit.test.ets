import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { LocalDataStore } from '../main/ets/common/storage/LocalDataStore';
import { AdminRepository } from '../main/ets/repositories/AdminRepository';
import { mockAdminProfile } from '../main/ets/mock/mockAdmin';
import { SessionStorage } from '../main/ets/common/storage/SessionStorage';
import { PreferenceStorage } from '../main/ets/common/storage/PreferenceStorage';
import { AdminCourseWritePayload, GradeAuditItem } from '../main/ets/models/Admin';
import { FileService } from '../main/ets/common/services/FileService';

async function clearLocalUnitState(): Promise<void> {
  await SessionStorage.get().clear();
  await PreferenceStorage.get().remove('local.adminGrades.v1');
  await PreferenceStorage.get().remove('local.adminCourses.v1');
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

    it('localDataStoreReturnsFallbackWhenPreferencesAreUnavailable', 0, async () => {
      const fallback: string[] = ['mock'];
      const result = await LocalDataStore.loadArray<string>('test.unavailable', fallback);
      expect(result.length).assertEqual(1);
      expect(result[0]).assertEqual('mock');
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
  });
}
