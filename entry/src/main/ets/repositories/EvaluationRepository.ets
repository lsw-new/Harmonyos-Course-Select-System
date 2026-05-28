// 评教仓储

import { BaseRepository } from './BaseRepository';
import { EvaluationTask, EvaluationQuestionnaire, EvaluationAnswer } from '../models/Evaluation';
import { mockEvaluationTasks, mockQuestionnaire } from '../mock/mockEvaluations';

export class EvaluationRepository extends BaseRepository {
  private static _instance?: EvaluationRepository;
  static get(): EvaluationRepository {
    if (!EvaluationRepository._instance) {
      EvaluationRepository._instance = new EvaluationRepository();
    }
    return EvaluationRepository._instance;
  }

  private tasks: EvaluationTask[] = JSON.parse(JSON.stringify(mockEvaluationTasks)) as EvaluationTask[];

  async getTasks(term?: string): Promise<EvaluationTask[]> {
    let items = this.tasks;
    if (term && term !== '全部') {
      items = items.filter((t) => t.term === term);
    }
    return this.delayCopy<EvaluationTask[]>(items);
  }

  async getQuestionnaire(taskId: string): Promise<EvaluationQuestionnaire> {
    const task = this.tasks.find((t) => t.id === taskId);
    if (!task) {
      return this.reject('评教任务不存在', 'notFound');
    }
    if (task.status !== 'open') {
      return this.reject(task.status === 'submitted' ? '已提交，不可重复填写' : '当前任务不在开放期');
    }
    return this.delayCopy<EvaluationQuestionnaire>(mockQuestionnaire);
  }

  async submit(taskId: string, answers: EvaluationAnswer[]): Promise<boolean> {
    const task = this.tasks.find((t) => t.id === taskId);
    if (!task) {
      return this.reject('评教任务不存在', 'notFound');
    }
    if (task.status !== 'open') {
      return this.reject('当前任务不在开放期');
    }
    if (!answers || answers.length === 0) {
      return this.reject('答案为空');
    }
    task.status = 'submitted';
    return this.delay<boolean>(true);
  }
}
