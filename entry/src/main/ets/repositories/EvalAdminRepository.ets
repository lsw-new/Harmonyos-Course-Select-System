// 评教管理仓储 · Évaluation Admin
// 拥有评教统计、评教期开关与问卷模板数据，经 LocalDataStore / PreferenceStorage 持久化。

import { BaseRepository } from './BaseRepository';
import {
  EvalAdminStats, RatingBucket, QuestionnaireTemplate, TemplateWritePayload
} from '../models/EvalAdminModels';
import { mockEvalAdminStats, mockEvalTemplates } from '../mock/mockEvalAdmin';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';
import { AuthorizationService } from '../common/security/AuthorizationService';

const KEY_EVAL_PERIOD = 'local.evalPeriod.v1';
const KEY_EVAL_TEMPLATES = 'local.evalTemplates.v1';
const TEMPLATE_STATUSES: string[] = ['enabled', 'disabled'];
const NAME_MIN = 1;
const NAME_MAX = 60;
const DESC_MAX = 160;
const QUESTION_MIN = 1;
const QUESTION_MAX = 50;
const CONTROL_CHAR_MAX = 31;
const DEL_CHAR_CODE = 127;

export class EvalAdminRepository extends BaseRepository {
  private static _instance?: EvalAdminRepository;
  static get(): EvalAdminRepository {
    if (!EvalAdminRepository._instance) {
      EvalAdminRepository._instance = new EvalAdminRepository();
    }
    return EvalAdminRepository._instance;
  }

  private templates: QuestionnaireTemplate[] = JSON.parse(JSON.stringify(mockEvalTemplates)) as QuestionnaireTemplate[];
  private periodOpen: boolean = mockEvalAdminStats.periodOpen;
  private isTemplatesLoaded: boolean = false;
  private isPeriodLoaded: boolean = false;

  // ===== 校验工具 =====

  private isFiniteNumber(value: number): boolean {
    return typeof value === 'number' && value === value && value !== Infinity && value !== -Infinity;
  }

  // 拒绝换行符与不可见控制字符（避免存入脏数据），不依赖正则字面量。
  private hasControlChar(value: string): boolean {
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i);
      if (code <= CONTROL_CHAR_MAX || code === DEL_CHAR_CODE) {
        return true;
      }
    }
    return false;
  }

  private isCleanText(value: string, min: number, max: number): boolean {
    if (typeof value !== 'string') {
      return false;
    }
    const text = value.trim();
    return text.length >= min && text.length <= max && !this.hasControlChar(text);
  }

  private isAllowedStatus(value: string): boolean {
    return TEMPLATE_STATUSES.indexOf(value) >= 0;
  }

  private isValidQuestionCount(value: number): boolean {
    return this.isFiniteNumber(value) && Math.floor(value) === value && value >= QUESTION_MIN && value <= QUESTION_MAX;
  }

  private validateTemplatePayload(payload: TemplateWritePayload, items: QuestionnaireTemplate[], editingId?: string): string {
    const name = payload.name.trim();
    const description = payload.description.trim();
    if (!this.isCleanText(name, NAME_MIN, NAME_MAX)) {
      return '问卷名称需为 1-60 字且不能包含换行或控制字符';
    }
    if (description.length > 0 && !this.isCleanText(description, 1, DESC_MAX)) {
      return '问卷描述需在 160 字以内且不能包含换行或控制字符';
    }
    if (!this.isValidQuestionCount(payload.questionCount)) {
      return '题目数量需为 1-50 的整数';
    }
    if (!this.isAllowedStatus(payload.status)) {
      return '问卷状态不合法';
    }
    const duplicated = items.some((item) => item.id !== editingId && item.name.trim().toLowerCase() === name.toLowerCase());
    if (duplicated) {
      return '问卷名称已存在';
    }
    return '';
  }

  private normalizeTemplatePayload(payload: TemplateWritePayload): TemplateWritePayload {
    const normalized: TemplateWritePayload = {
      name: payload.name.trim(),
      description: payload.description.trim(),
      questionCount: payload.questionCount,
      status: payload.status
    };
    return normalized;
  }

  // ===== 模板持久化（含读取时净化，回退 mock）=====

  private isValidStoredTemplate(item: QuestionnaireTemplate): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (!this.isCleanText(item.name, NAME_MIN, NAME_MAX)) {
      return false;
    }
    if (typeof item.description !== 'string' || this.hasControlChar(item.description) || item.description.trim().length > DESC_MAX) {
      return false;
    }
    if (!this.isValidQuestionCount(item.questionCount) || !this.isAllowedStatus(item.status)) {
      return false;
    }
    return true;
  }

  private sanitizeTemplates(items: QuestionnaireTemplate[]): QuestionnaireTemplate[] {
    const ids: string[] = [];
    const sanitized: QuestionnaireTemplate[] = [];
    items.forEach((item) => {
      if (!this.isValidStoredTemplate(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const next: QuestionnaireTemplate = {
        id: id,
        name: item.name.trim(),
        description: item.description.trim(),
        questionCount: item.questionCount,
        status: item.status
      };
      sanitized.push(next);
    });
    return sanitized;
  }

  private async getTemplateItems(): Promise<QuestionnaireTemplate[]> {
    if (!this.isTemplatesLoaded) {
      const stored = await LocalDataStore.loadArray<QuestionnaireTemplate>(KEY_EVAL_TEMPLATES, mockEvalTemplates);
      const sanitized = this.sanitizeTemplates(stored);
      this.templates = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockEvalTemplates)) as QuestionnaireTemplate[];
      this.isTemplatesLoaded = true;
    }
    return this.templates;
  }

  private async saveTemplates(next: QuestionnaireTemplate[]): Promise<void> {
    this.templates = next;
    this.isTemplatesLoaded = true;
    await LocalDataStore.saveArray<QuestionnaireTemplate>(KEY_EVAL_TEMPLATES, next);
  }

  // ===== 评教期持久化 =====

  private async getPeriodOpen(): Promise<boolean> {
    if (!this.isPeriodLoaded) {
      this.periodOpen = await PreferenceStorage.get().getBoolean(KEY_EVAL_PERIOD, mockEvalAdminStats.periodOpen);
      this.isPeriodLoaded = true;
    }
    return this.periodOpen;
  }

  // ===== 对外接口 =====

  async getStats(): Promise<EvalAdminStats> {
    const periodOpen = await this.getPeriodOpen();
    const buckets: RatingBucket[] = mockEvalAdminStats.ratingDistribution.map((b: RatingBucket) => {
      const copy: RatingBucket = { star: b.star, count: b.count };
      return copy;
    });
    const stats: EvalAdminStats = {
      term: mockEvalAdminStats.term,
      periodOpen: periodOpen,
      participationRate: mockEvalAdminStats.participationRate,
      completionRate: mockEvalAdminStats.completionRate,
      averageScore: mockEvalAdminStats.averageScore,
      ratingDistribution: buckets
    };
    return this.delayCopy<EvalAdminStats>(stats);
  }

  async setPeriodOpen(open: boolean): Promise<boolean> {
    if (!AuthorizationService.hasAdminPermission('evaluation.manage', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    this.periodOpen = open;
    this.isPeriodLoaded = true;
    await PreferenceStorage.get().putBoolean(KEY_EVAL_PERIOD, open);
    return this.delay<boolean>(open);
  }

  async getTemplates(): Promise<QuestionnaireTemplate[]> {
    const items = await this.getTemplateItems();
    return this.delayCopy<QuestionnaireTemplate[]>(items);
  }

  async createTemplate(payload: TemplateWritePayload): Promise<QuestionnaireTemplate> {
    if (!AuthorizationService.hasAdminPermission('evaluation.manage', 'create')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const items = await this.getTemplateItems();
    const normalized = this.normalizeTemplatePayload(payload);
    const error = this.validateTemplatePayload(normalized, items);
    if (error.length > 0) {
      return this.reject(error);
    }
    const item: QuestionnaireTemplate = {
      id: `qt-${Date.now()}`,
      name: normalized.name,
      description: normalized.description,
      questionCount: normalized.questionCount,
      status: normalized.status
    };
    const next = [item].concat(items);
    await this.saveTemplates(next);
    return this.delayCopy<QuestionnaireTemplate>(item);
  }

  async updateTemplate(id: string, payload: TemplateWritePayload): Promise<QuestionnaireTemplate> {
    if (!AuthorizationService.hasAdminPermission('evaluation.manage', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const items = await this.getTemplateItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('问卷模板不存在', 'notFound');
    }
    const normalized = this.normalizeTemplatePayload(payload);
    const error = this.validateTemplatePayload(normalized, items, id);
    if (error.length > 0) {
      return this.reject(error);
    }
    const updated: QuestionnaireTemplate = {
      id: target.id,
      name: normalized.name,
      description: normalized.description,
      questionCount: normalized.questionCount,
      status: normalized.status
    };
    const next = items.map((item) => item.id === id ? updated : item);
    await this.saveTemplates(next);
    return this.delayCopy<QuestionnaireTemplate>(updated);
  }

  async deleteTemplate(id: string): Promise<boolean> {
    if (!AuthorizationService.hasAdminPermission('evaluation.manage', 'delete')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const items = await this.getTemplateItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('问卷模板不存在', 'notFound');
    }
    const next = items.filter((item) => item.id !== id);
    await this.saveTemplates(next);
    return this.delay<boolean>(true);
  }
}
