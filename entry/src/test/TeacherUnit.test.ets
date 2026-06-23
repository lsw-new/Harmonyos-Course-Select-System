// 教师端仓储 mock 模式单测（roadmap #6 配套）。
// 重点：AppConfig.runtimeMode 默认 'remote'（走网络），故每个用例前切到 'mock'、用例后恢复，
// 避免污染其它套件或触发真实网络调用。断言值以 TeacherRepository 实际 mock 返回为准。

import { describe, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { AppConfig, RuntimeMode } from '../main/ets/app/AppConfig';
import { TeacherRepository } from '../main/ets/repositories/TeacherRepository';
import {
  TeacherDashboard, TeacherCourse, TeacherEval,
  TeacherScheduleItem, TeacherEvalBreakdown
} from '../main/ets/models/Teacher';

export default function teacherUnitTest() {
  describe('teacherUnitTest', () => {
    let prevMode: string = AppConfig.runtimeMode;

    beforeEach(() => {
      prevMode = AppConfig.runtimeMode;
      AppConfig.runtimeMode = 'mock';
    });
    afterEach(() => {
      AppConfig.runtimeMode = prevMode as RuntimeMode;
    });
    afterAll(() => {
      AppConfig.runtimeMode = 'remote';
    });

    it('teacherGetDashboardReturnsMockConstants', 0, async () => {
      expect(AppConfig.useMock).assertTrue();
      const dashboard: TeacherDashboard = await TeacherRepository.get().getDashboard();
      expect(dashboard.courseCount).assertEqual(2);
      expect(dashboard.studentCount).assertEqual(94);
      expect(dashboard.pendingGradeCount).assertEqual(1);
      expect(dashboard.evalAvg).assertEqual(4.7);
      expect(dashboard.evalSubmitted).assertEqual(47);
    });

    it('teacherGetCoursesReturnsMockListWithTypedFields', 0, async () => {
      const courses: TeacherCourse[] = await TeacherRepository.get().getCourses();
      expect(courses.length).assertEqual(2);

      const first: TeacherCourse = courses[0];
      expect(first.courseId).assertEqual('mock-c1');
      expect(first.name).assertEqual('编译原理');
      expect(first.code).assertEqual('CS2103');
      expect(typeof first.credit === 'number').assertTrue();
      expect(first.credit).assertEqual(3);
      expect(first.studentCount).assertEqual(47);
      expect(first.teachingClassName).assertEqual('23计算机U9');

      const second: TeacherCourse = courses[1];
      expect(second.courseId).assertEqual('mock-c2');
      expect(second.name).assertEqual('操作系统');
      expect(second.credit).assertEqual(4);
    });

    it('teacherGetEvalBreakdownReturnsTypedQuestions', 0, async () => {
      const breakdown: TeacherEvalBreakdown[] = await TeacherRepository.get().getEvalBreakdown('any');
      expect(breakdown.length).assertEqual(3);

      breakdown.forEach((item: TeacherEvalBreakdown) => {
        expect(item.questionId.length > 0).assertTrue();
        expect(item.title.length > 0).assertTrue();
        expect(typeof item.avg === 'number').assertTrue();
        expect(typeof item.count === 'number').assertTrue();
        expect(item.count).assertEqual(30);
      });

      const firstQuestion: TeacherEvalBreakdown = breakdown[0];
      expect(firstQuestion.questionId).assertEqual('q1');
      expect(firstQuestion.avg).assertEqual(4.7);
    });

    it('teacherGetEvaluationsReturnsTypedAggregates', 0, async () => {
      const evals: TeacherEval[] = await TeacherRepository.get().getEvaluations();
      expect(evals.length).assertEqual(2);

      evals.forEach((item: TeacherEval) => {
        const avgIsNumberOrNull: boolean = (typeof item.avgScore === 'number') || (item.avgScore === null);
        expect(avgIsNumberOrNull).assertTrue();
        expect(typeof item.taskCount === 'number').assertTrue();
        expect(typeof item.submittedCount === 'number').assertTrue();
        expect(item.taskCount).assertEqual(47);
      });

      const first: TeacherEval = evals[0];
      expect(first.courseId).assertEqual('mock-c1');
      expect(first.courseName).assertEqual('编译原理');
      expect(first.submittedCount).assertEqual(30);
      expect(first.avgScore).assertEqual(4.6);
    });

    it('teacherGetScheduleReturnsTypedMockItems', 0, async () => {
      const schedule: TeacherScheduleItem[] = await TeacherRepository.get().getSchedule();
      expect(schedule.length).assertEqual(2);

      schedule.forEach((item: TeacherScheduleItem) => {
        expect(item.itemId.length > 0).assertTrue();
        expect(item.courseName.length > 0).assertTrue();
        expect(typeof item.weekday === 'number').assertTrue();
        expect(typeof item.periodStart === 'number').assertTrue();
        expect(typeof item.periodEnd === 'number').assertTrue();
        expect(item.term).assertEqual('2025-2026-2');
      });

      const first: TeacherScheduleItem = schedule[0];
      expect(first.itemId).assertEqual('ms1');
      expect(first.courseName).assertEqual('编译原理');
      expect(first.weekday).assertEqual(1);
      expect(first.periodStart).assertEqual(1);
      expect(first.periodEnd).assertEqual(2);
      expect(first.startTime).assertEqual('08:00');
    });
  });
}
