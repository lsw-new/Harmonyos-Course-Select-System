// 评教仓储

import { BaseRepository } from './BaseRepository';
import { EvaluationTask, EvaluationQuestionnaire, EvaluationAnswer, EvaluationStatus } from '../models/Evaluation';
import { mockEvaluationTasks, mockQuestionnaire } from '../mock/mockEvaluations';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteEvalTask } from '../common/remote/RemoteApi';

const KEY_EVALUATION_TASKS = 'local.evaluationTasks.v1';
const EVALUATION_STATUSES: string[] = ['open', 'submitted', 'closed'];
const CONTROL_CHAR_PATTERN: RegExp = /[\r\n\u0000-\u001f\u007f]/;

export class EvaluationRepository extends BaseRepository {
  private static _instance?: EvaluationRepository;
  static get(): EvaluationRepository {
    if (!EvaluationRepository._instance) {
      EvaluationRepository._instance = new EvaluationRepository();
    }
    return EvaluationRepository._instance;
  }

  private tasks: EvaluationTask[] = JSON.parse(JSON.stringify(mockEvaluationTasks)) as EvaluationTask[];
  private isTasksLoaded: boolean = false;

  // 按当前登录学生隔离持久化 key，避免换账号串数据；未登录时回退原 base。
  private scopedKey(base: string): string {
    const s = SessionStorage.get().getStudent();
    return (s && s.studentId.length > 0) ? `${base}.${s.studentId}` : base;
  }

  private isCleanText(value: string, min: number, max: number): boolean {
    if (typeof value !== 'string') {
      return false;
    }
    const text = value.trim();
    return text.length >= min && text.length <= max && !CONTROL_CHAR_PATTERN.test(text);
  }

  private isAllowedStatus(value: string): boolean {
    return EVALUATION_STATUSES.indexOf(value) >= 0;
  }

  private isValidTask(item: EvaluationTask): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64) || !this.isCleanText(item.term, 1, 32)) {
      return false;
    }
    if (!this.isCleanText(item.courseCode, 1, 32) || !this.isCleanText(item.courseName, 1, 80)) {
      return false;
    }
    if (!this.isCleanText(item.courseCategory, 1, 32) || !this.isCleanText(item.teacherName, 1, 32)) {
      return false;
    }
    if (!this.isCleanText(item.questionnaireName, 1, 80) || !this.isAllowedStatus(item.status)) {
      return false;
    }
    if (item.openTime !== undefined && !this.isCleanText(item.openTime, 1, 40)) {
      return false;
    }
    if (item.closeTime !== undefined && !this.isCleanText(item.closeTime, 1, 40)) {
      return false;
    }
    if (item.closedReason !== undefined && !this.isCleanText(item.closedReason, 1, 120)) {
      return false;
    }
    return true;
  }

  private sanitizeTasks(items: EvaluationTask[]): EvaluationTask[] {
    const ids: string[] = [];
    const sanitized: EvaluationTask[] = [];
    items.forEach((item) => {
      if (!this.isValidTask(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const task: EvaluationTask = {
        id,
        term: item.term.trim(),
        courseCode: item.courseCode.trim(),
        courseName: item.courseName.trim(),
        courseCategory: item.courseCategory.trim(),
        teacherName: item.teacherName.trim(),
        questionnaireName: item.questionnaireName.trim(),
        status: item.status,
        openTime: item.openTime,
        closeTime: item.closeTime,
        closedReason: item.closedReason
      };
      sanitized.push(task);
    });
    return sanitized;
  }

  private async getTaskItems(): Promise<EvaluationTask[]> {
    if (!this.isTasksLoaded) {
      const stored = await LocalDataStore.loadArray<EvaluationTask>(this.scopedKey(KEY_EVALUATION_TASKS), mockEvaluationTasks);
      const sanitized = this.sanitizeTasks(stored);
      this.tasks = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockEvaluationTasks)) as EvaluationTask[];
      this.isTasksLoaded = true;
    }
    return this.tasks;
  }

  private async saveTasks(next: EvaluationTask[]): Promise<void> {
    const sanitized = this.sanitizeTasks(next);
    this.tasks = sanitized;
    this.isTasksLoaded = true;
    await LocalDataStore.saveArray<EvaluationTask>(this.scopedKey(KEY_EVALUATION_TASKS), sanitized);
  }

  private mapEvalCategory(c: string): string {
    if (c === 'required') {
      return '必修';
    }
    if (c === 'elective') {
      return '选修';
    }
    if (c === 'public') {
      return '公选';
    }
    if (c === 'practice') {
      return '实践';
    }
    return c;
  }

  private remoteToEvalTask(t: RemoteEvalTask): EvaluationTask {
    const item: EvaluationTask = {
      id: t.id,
      term: t.term,
      courseCode: t.courseCode,
      courseName: t.courseName,
      courseCategory: this.mapEvalCategory(t.courseCategory),
      teacherName: t.teacherName,
      questionnaireName: t.questionnaireName,
      status: t.status as EvaluationStatus
    };
    if (t.openTime.length > 0) {
      item.openTime = t.openTime;
    }
    if (t.closeTime.length > 0) {
      item.closeTime = t.closeTime;
    }
    return item;
  }

  async getTasks(term?: string): Promise<EvaluationTask[]> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.listEvaluations(student.studentId, term);
          return this.delayCopy<EvaluationTask[]>(remote.map((t) => this.remoteToEvalTask(t)));
        } catch (e) {
          // 远程失败回退本地
        }
      }
    }
    let items = await this.getTaskItems();
    if (term && term !== '全部') {
      items = items.filter((t) => t.term === term);
    }
    return this.delayCopy<EvaluationTask[]>(items);
  }

  async getQuestionnaire(taskId: string): Promise<EvaluationQuestionnaire> {
    const tasks = await this.getTaskItems();
    const task = tasks.find((t) => t.id === taskId);
    if (!task) {
      return this.reject('评教任务不存在', 'notFound');
    }
    if (task.status !== 'open') {
      return this.reject(task.status === 'submitted' ? '已提交，不可重复填写' : '当前任务不在开放期');
    }
    return this.delayCopy<EvaluationQuestionnaire>(mockQuestionnaire);
  }

  async submit(taskId: string, answers: EvaluationAnswer[]): Promise<boolean> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          await RemoteApi.submitEvaluation(student.studentId, taskId, answers);
          return this.delay<boolean>(true);
        } catch (e) {
          return this.reject((e instanceof Error) ? e.message : String(e));
        }
      }
    }
    const tasks = await this.getTaskItems();
    const task = tasks.find((t) => t.id === taskId);
    if (!task) {
      return this.reject('评教任务不存在', 'notFound');
    }
    if (task.status !== 'open') {
      return this.reject('当前任务不在开放期');
    }
    if (!answers || answers.length === 0) {
      return this.reject('答案为空');
    }
    const next = tasks.map((item) => {
      if (item.id !== taskId) {
        return item;
      }
      const updated: EvaluationTask = {
        id: item.id,
        term: item.term,
        courseCode: item.courseCode,
        courseName: item.courseName,
        courseCategory: item.courseCategory,
        teacherName: item.teacherName,
        questionnaireName: item.questionnaireName,
        status: 'submitted',
        openTime: item.openTime,
        closeTime: item.closeTime,
        closedReason: item.closedReason
      };
      return updated;
    });
    await this.saveTasks(next);
    return this.delay<boolean>(true);
  }
}
