// 系统配置仓储 · 校历 / 审批流 / 消息模板 / 安全策略 / 管理员改密
// 路由守卫已在页面层保护，本仓储不再做权限校验。

import { BaseRepository } from './BaseRepository';
import {
  CalendarEvent, CalendarEventType, CalendarEventPayload,
  ApprovalNode, MsgTemplate, MsgTemplatePayload, SecurityPolicy
} from '../models/SysConfigModels';
import {
  mockCalendarEvents, mockApprovalNodes, mockMsgTemplates, mockSecurityPolicy
} from '../mock/mockSysConfig';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { PreferenceStorage } from '../common/storage/PreferenceStorage';
import { AuthorizationService } from '../common/security/AuthorizationService';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteCalendarEvent, CalendarEventBody } from '../common/remote/RemoteApi';

const KEY_CALENDAR = 'local.calendar.v1';
const KEY_APPROVAL_FLOW = 'local.approvalFlow.v1';
const KEY_MSG_TEMPLATES = 'local.msgTemplates.v1';

// 安全策略各开关使用 PreferenceStorage 单独存储
const SEC_TWO_FACTOR = 'sec.twoFactor';
const SEC_FORCE_STRONG = 'sec.forceStrongPwd';
const SEC_LOCK_ON_FAIL = 'sec.lockOnFailure';
const SEC_AUTO_LOGOUT = 'sec.autoLogout';
const SEC_AUDIT_LOGGING = 'sec.auditLogging';

const CALENDAR_TYPES: string[] = ['term', 'exam', 'holiday', 'selection', 'makeup', 'other'];
const DATE_PATTERN: RegExp = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
const PWD_LETTER_PATTERN: RegExp = /[A-Za-z]/;
const PWD_DIGIT_PATTERN: RegExp = /[0-9]/;
const MIN_PWD_LENGTH = 8;

export class SysConfigRepository extends BaseRepository {
  private static _instance?: SysConfigRepository;
  static get(): SysConfigRepository {
    if (!SysConfigRepository._instance) {
      SysConfigRepository._instance = new SysConfigRepository();
    }
    return SysConfigRepository._instance;
  }

  private calendar: CalendarEvent[] = JSON.parse(JSON.stringify(mockCalendarEvents)) as CalendarEvent[];
  private flow: ApprovalNode[] = JSON.parse(JSON.stringify(mockApprovalNodes)) as ApprovalNode[];
  private templates: MsgTemplate[] = JSON.parse(JSON.stringify(mockMsgTemplates)) as MsgTemplate[];
  private isCalendarLoaded: boolean = false;
  private isFlowLoaded: boolean = false;
  private isTemplatesLoaded: boolean = false;

  // ---------- 通用校验 ----------
  // 不含换行/制表/控制字符（ASCII < 32 或 == 127）
  private hasControlChar(value: string): boolean {
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i);
      if (code < 32 || code === 127) {
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

  private isAllowedCalendarType(value: string): boolean {
    return CALENDAR_TYPES.indexOf(value) >= 0;
  }

  // ---------- 校历 ----------
  private async getCalendarItems(): Promise<CalendarEvent[]> {
    if (!this.isCalendarLoaded) {
      const stored = await LocalDataStore.loadArray<CalendarEvent>(KEY_CALENDAR, mockCalendarEvents);
      const sanitized = this.sanitizeCalendar(stored);
      this.calendar = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockCalendarEvents)) as CalendarEvent[];
      this.isCalendarLoaded = true;
    }
    return this.calendar;
  }

  private isValidStoredEvent(item: CalendarEvent): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (typeof item.date !== 'string' || !DATE_PATTERN.test(item.date.trim())) {
      return false;
    }
    if (!this.isCleanText(item.title, 1, 60)) {
      return false;
    }
    return this.isAllowedCalendarType(item.type);
  }

  private sanitizeCalendar(items: CalendarEvent[]): CalendarEvent[] {
    const ids: string[] = [];
    const result: CalendarEvent[] = [];
    items.forEach((item) => {
      if (!this.isValidStoredEvent(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const next: CalendarEvent = {
        id: id,
        date: item.date.trim(),
        title: item.title.trim(),
        type: item.type
      };
      result.push(next);
    });
    return result;
  }

  private async saveCalendar(next: CalendarEvent[]): Promise<void> {
    this.calendar = next;
    this.isCalendarLoaded = true;
    await LocalDataStore.saveArray<CalendarEvent>(KEY_CALENDAR, next);
  }

  // \u8fdc\u7a0b\u65e5\u5386\u4e8b\u4ef6 \u2192 \u672c\u5730\u6a21\u578b\uff08type \u8bcd\u8868\u4e24\u7aef\u4e00\u81f4\uff09
  private remoteToCalendarEvent(r: RemoteCalendarEvent): CalendarEvent {
    const event: CalendarEvent = {
      id: r.id,
      date: r.date,
      title: r.title,
      type: r.type as CalendarEventType
    };
    return event;
  }

  async getCalendarEvents(): Promise<CalendarEvent[]> {
    if (AppConfig.useRemote) {
      try {
        // \u516c\u5171\u7aef\u70b9\uff1a\u5b66\u751f\u7aef\uff08\u8003\u8bd5\u9875\u6821\u5386\u8282\u70b9\uff09\u4e0e\u7ba1\u7406\u7aef\u65e5\u5386\u9875\u5171\u7528
        const remote = await RemoteApi.calendarEvents();
        return this.delayCopy<CalendarEvent[]>(remote.map((r) => this.remoteToCalendarEvent(r)));
      } catch (e) {
        // \u8fdc\u7a0b\u5931\u8d25\uff1aremote \u6a21\u5f0f\u7981\u6b62\u9759\u9ed8\u56de\u9000\u65f6\u76f4\u63a5\u629b\u9519\uff0c\u4ea4\u7531\u9875\u9762\u9519\u8bef\u6001\u5448\u73b0
        if (!AppConfig.allowMockFallbackInRemote) {
          throw new Error('\u8fdc\u7a0b\u670d\u52a1\u5f02\u5e38\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
        }
        // \u8fdc\u7a0b\u5931\u8d25\u56de\u9000\u672c\u5730\u6821\u5386
      }
    }
    const items = await this.getCalendarItems();
    return this.delayCopy<CalendarEvent[]>(items);
  }

  async addCalendarEvent(payload: CalendarEventPayload): Promise<CalendarEvent> {
    if (!AuthorizationService.hasAdminPermission('system.config', 'create')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    if (AppConfig.useRemote) {
      try {
        const body: CalendarEventBody = { date: payload.date, title: payload.title, type: payload.type };
        const remote = await RemoteApi.adminAddCalendarEvent(body);
        return this.delayCopy<CalendarEvent>(this.remoteToCalendarEvent(remote));
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const date = (payload.date ?? '').trim();
    const title = (payload.title ?? '').trim();
    if (!DATE_PATTERN.test(date)) {
      return this.reject('日期格式需为 YYYY-MM-DD');
    }
    if (!this.isCleanText(title, 1, 60)) {
      return this.reject('标题需为 1-60 字且不能包含换行或控制字符');
    }
    if (!this.isAllowedCalendarType(payload.type)) {
      return this.reject('事件类型不合法');
    }
    const items = await this.getCalendarItems();
    const event: CalendarEvent = {
      id: `cal-${Date.now()}`,
      date: date,
      title: title,
      type: payload.type as CalendarEventType
    };
    const next = [event].concat(items);
    await this.saveCalendar(next);
    return this.delayCopy<CalendarEvent>(event);
  }

  async deleteCalendarEvent(id: string): Promise<boolean> {
    if (!AuthorizationService.hasAdminPermission('system.config', 'delete')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    if (AppConfig.useRemote) {
      try {
        await RemoteApi.adminDeleteCalendarEvent(id);
        return this.delay<boolean>(true);
      } catch (e) {
        return this.reject((e instanceof Error) ? e.message : String(e));
      }
    }
    const items = await this.getCalendarItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('校历事件不存在', 'notFound');
    }
    const next = items.filter((item) => item.id !== id);
    await this.saveCalendar(next);
    return this.delay<boolean>(true);
  }

  // ---------- 审批流 ----------
  private async getFlowItems(): Promise<ApprovalNode[]> {
    if (!this.isFlowLoaded) {
      const stored = await LocalDataStore.loadArray<ApprovalNode>(KEY_APPROVAL_FLOW, mockApprovalNodes);
      const sanitized = this.sanitizeFlow(stored);
      this.flow = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockApprovalNodes)) as ApprovalNode[];
      this.isFlowLoaded = true;
    }
    return this.flow;
  }

  private isValidStoredNode(item: ApprovalNode): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (!this.isCleanText(item.name, 1, 40) || !this.isCleanText(item.approverRole, 1, 40)) {
      return false;
    }
    if (typeof item.enabled !== 'boolean') {
      return false;
    }
    return typeof item.order === 'number' && item.order === item.order;
  }

  private sanitizeFlow(items: ApprovalNode[]): ApprovalNode[] {
    const ids: string[] = [];
    const result: ApprovalNode[] = [];
    items.forEach((item) => {
      if (!this.isValidStoredNode(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const next: ApprovalNode = {
        id: id,
        name: item.name.trim(),
        approverRole: item.approverRole.trim(),
        enabled: item.enabled,
        order: item.order
      };
      result.push(next);
    });
    result.sort((a, b) => a.order - b.order);
    return result;
  }

  private async saveFlow(next: ApprovalNode[]): Promise<void> {
    this.flow = next;
    this.isFlowLoaded = true;
    await LocalDataStore.saveArray<ApprovalNode>(KEY_APPROVAL_FLOW, next);
  }

  async getApprovalFlow(): Promise<ApprovalNode[]> {
    const items = await this.getFlowItems();
    return this.delayCopy<ApprovalNode[]>(items);
  }

  async updateApprovalFlow(nodes: ApprovalNode[]): Promise<ApprovalNode[]> {
    if (!AuthorizationService.hasAdminPermission('system.config', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const sanitized = this.sanitizeFlow(nodes);
    if (sanitized.length === 0) {
      return this.reject('审批流节点不合法');
    }
    await this.saveFlow(sanitized);
    return this.delayCopy<ApprovalNode[]>(sanitized);
  }

  // ---------- 消息模板 ----------
  private async getTemplateItems(): Promise<MsgTemplate[]> {
    if (!this.isTemplatesLoaded) {
      const stored = await LocalDataStore.loadArray<MsgTemplate>(KEY_MSG_TEMPLATES, mockMsgTemplates);
      const sanitized = this.sanitizeTemplates(stored);
      this.templates = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockMsgTemplates)) as MsgTemplate[];
      this.isTemplatesLoaded = true;
    }
    return this.templates;
  }

  private isValidStoredTemplate(item: MsgTemplate): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64)) {
      return false;
    }
    if (!this.isCleanText(item.name, 1, 40) || !this.isCleanText(item.channel, 1, 20)) {
      return false;
    }
    if (typeof item.content !== 'string') {
      return false;
    }
    const content = item.content.trim();
    return content.length >= 1 && content.length <= 500;
  }

  private sanitizeTemplates(items: MsgTemplate[]): MsgTemplate[] {
    const ids: string[] = [];
    const result: MsgTemplate[] = [];
    items.forEach((item) => {
      if (!this.isValidStoredTemplate(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const next: MsgTemplate = {
        id: id,
        name: item.name.trim(),
        channel: item.channel.trim(),
        content: item.content.trim()
      };
      result.push(next);
    });
    return result;
  }

  private async saveTemplates(next: MsgTemplate[]): Promise<void> {
    this.templates = next;
    this.isTemplatesLoaded = true;
    await LocalDataStore.saveArray<MsgTemplate>(KEY_MSG_TEMPLATES, next);
  }

  private validateTemplatePayload(payload: MsgTemplatePayload): string {
    if (!this.isCleanText(payload.name, 1, 40)) {
      return '模板名称不能为空且不超过 40 字';
    }
    if (!this.isCleanText(payload.channel, 1, 20)) {
      return '渠道不能为空';
    }
    const content = (payload.content ?? '').trim();
    if (content.length < 1 || content.length > 500) {
      return '模板内容不能为空且不超过 500 字';
    }
    return '';
  }

  async getMsgTemplates(): Promise<MsgTemplate[]> {
    const items = await this.getTemplateItems();
    return this.delayCopy<MsgTemplate[]>(items);
  }

  async createMsgTemplate(payload: MsgTemplatePayload): Promise<MsgTemplate> {
    if (!AuthorizationService.hasAdminPermission('system.config', 'create')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const error = this.validateTemplatePayload(payload);
    if (error.length > 0) {
      return this.reject(error);
    }
    const items = await this.getTemplateItems();
    const item: MsgTemplate = {
      id: `tpl-${Date.now()}`,
      name: payload.name.trim(),
      channel: payload.channel.trim(),
      content: payload.content.trim()
    };
    const next = [item].concat(items);
    await this.saveTemplates(next);
    return this.delayCopy<MsgTemplate>(item);
  }

  async updateMsgTemplate(id: string, payload: MsgTemplatePayload): Promise<MsgTemplate> {
    if (!AuthorizationService.hasAdminPermission('system.config', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const items = await this.getTemplateItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('消息模板不存在', 'notFound');
    }
    const error = this.validateTemplatePayload(payload);
    if (error.length > 0) {
      return this.reject(error);
    }
    const updated: MsgTemplate = {
      id: target.id,
      name: payload.name.trim(),
      channel: payload.channel.trim(),
      content: payload.content.trim()
    };
    const next = items.map((item) => item.id === id ? updated : item);
    await this.saveTemplates(next);
    return this.delayCopy<MsgTemplate>(updated);
  }

  async deleteMsgTemplate(id: string): Promise<boolean> {
    if (!AuthorizationService.hasAdminPermission('system.config', 'delete')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const items = await this.getTemplateItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('消息模板不存在', 'notFound');
    }
    const next = items.filter((item) => item.id !== id);
    await this.saveTemplates(next);
    return this.delay<boolean>(true);
  }

  // ---------- 安全策略 ----------
  async getSecurityPolicy(): Promise<SecurityPolicy> {
    const store = PreferenceStorage.get();
    const policy: SecurityPolicy = {
      twoFactor: await store.getBoolean(SEC_TWO_FACTOR, mockSecurityPolicy.twoFactor),
      forceStrongPwd: await store.getBoolean(SEC_FORCE_STRONG, mockSecurityPolicy.forceStrongPwd),
      lockOnFailure: await store.getBoolean(SEC_LOCK_ON_FAIL, mockSecurityPolicy.lockOnFailure),
      autoLogout: await store.getBoolean(SEC_AUTO_LOGOUT, mockSecurityPolicy.autoLogout),
      auditLogging: await store.getBoolean(SEC_AUDIT_LOGGING, mockSecurityPolicy.auditLogging)
    };
    return this.delay<SecurityPolicy>(policy);
  }

  private securityKeyFor(key: string): string {
    if (key === 'twoFactor') return SEC_TWO_FACTOR;
    if (key === 'forceStrongPwd') return SEC_FORCE_STRONG;
    if (key === 'lockOnFailure') return SEC_LOCK_ON_FAIL;
    if (key === 'autoLogout') return SEC_AUTO_LOGOUT;
    if (key === 'auditLogging') return SEC_AUDIT_LOGGING;
    return '';
  }

  async setSecurityToggle(key: string, value: boolean): Promise<boolean> {
    if (!AuthorizationService.hasAdminPermission('system.config', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const prefKey = this.securityKeyFor(key);
    if (prefKey.length === 0) {
      return this.reject('未知的安全策略项');
    }
    await PreferenceStorage.get().putBoolean(prefKey, value);
    return this.delay<boolean>(true);
  }

  // ---------- 管理员改密（仅 mock 校验，不调用 AuthRepository） ----------
  async changeAdminPassword(oldPwd: string, newPwd: string): Promise<boolean> {
    if (!AuthorizationService.isAdminAuthenticated()) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const oldValue = (oldPwd ?? '').trim();
    const newValue = newPwd ?? '';
    if (oldValue.length === 0) {
      return this.reject('请输入原密码');
    }
    if (newValue.length < MIN_PWD_LENGTH) {
      return this.reject('新密码长度至少为 8 位');
    }
    if (!PWD_LETTER_PATTERN.test(newValue) || !PWD_DIGIT_PATTERN.test(newValue)) {
      return this.reject('新密码需同时包含字母和数字');
    }
    if (newValue === oldValue) {
      return this.reject('新密码不能与原密码相同');
    }
    return this.delay<boolean>(true);
  }
}
