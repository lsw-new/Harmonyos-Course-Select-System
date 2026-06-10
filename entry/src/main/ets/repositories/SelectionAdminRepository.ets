// 选课轮次管理 · 仓储
// 负责轮次状态机（启动/暂停/结束）、起止时间编辑与冲突明细查询，
// 通过 LocalDataStore 持久化，重启后仍保留改动。

import { BaseRepository } from './BaseRepository';
import { AdminRound, RoundStatus, RoundConflict, RoundTimePayload } from '../models/SelectionAdminModels';
import { mockAdminRounds, mockRoundConflicts } from '../mock/mockSelectionAdmin';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { AuthorizationService } from '../common/security/AuthorizationService';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemoteAdminRound, RemoteRoundLite } from '../common/remote/RemoteApi';

const KEY_ADMIN_ROUNDS = 'local.adminRounds.v1';
const CONTROL_CHAR_PATTERN: RegExp = new RegExp("[\r\n\u0000-\u001f\u007f]");
// 起止时间形如 2026-05-20 09:00
const TIME_PATTERN: RegExp = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/;

export class SelectionAdminRepository extends BaseRepository {
  private static _instance?: SelectionAdminRepository;
  static get(): SelectionAdminRepository {
    if (!SelectionAdminRepository._instance) {
      SelectionAdminRepository._instance = new SelectionAdminRepository();
    }
    return SelectionAdminRepository._instance;
  }

  private rounds: AdminRound[] = JSON.parse(JSON.stringify(mockAdminRounds)) as AdminRound[];
  private isRoundsLoaded: boolean = false;

  private async getRoundItems(): Promise<AdminRound[]> {
    if (!this.isRoundsLoaded) {
      const stored = await LocalDataStore.loadArray<AdminRound>(KEY_ADMIN_ROUNDS, mockAdminRounds);
      const sanitized = this.sanitizeRounds(stored);
      this.rounds = sanitized.length > 0 ? sanitized : JSON.parse(JSON.stringify(mockAdminRounds)) as AdminRound[];
      this.isRoundsLoaded = true;
    }
    return this.rounds;
  }

  private async saveRounds(next: AdminRound[]): Promise<void> {
    this.rounds = next;
    this.isRoundsLoaded = true;
    await LocalDataStore.saveArray<AdminRound>(KEY_ADMIN_ROUNDS, next);
  }

  private isFiniteNumber(value: number): boolean {
    return typeof value === 'number' && value === value && value !== Infinity && value !== -Infinity;
  }

  private isAllowedStatus(value: string): boolean {
    return value === 'notStarted' || value === 'running' || value === 'paused' || value === 'ended';
  }

  private isCleanText(value: string, min: number, max: number): boolean {
    if (typeof value !== 'string') {
      return false;
    }
    const text = value.trim();
    return text.length >= min && text.length <= max && !CONTROL_CHAR_PATTERN.test(text);
  }

  private isValidTime(value: string): boolean {
    return typeof value === 'string' && TIME_PATTERN.test(value.trim());
  }

  private isValidStoredRound(item: AdminRound): boolean {
    if (!item || typeof item !== 'object') {
      return false;
    }
    if (!this.isCleanText(item.id, 1, 64) || !this.isCleanText(item.name, 1, 64)) {
      return false;
    }
    if (!this.isAllowedStatus(item.status)) {
      return false;
    }
    if (!this.isValidTime(item.startTime) || !this.isValidTime(item.endTime)) {
      return false;
    }
    if (!this.isFiniteNumber(item.progressPercent) || item.progressPercent < 0 || item.progressPercent > 100) {
      return false;
    }
    if (!this.isFiniteNumber(item.participantCount) || item.participantCount < 0) {
      return false;
    }
    if (!this.isFiniteNumber(item.selectionCount) || item.selectionCount < 0) {
      return false;
    }
    if (!this.isFiniteNumber(item.averageCredit) || item.averageCredit < 0) {
      return false;
    }
    if (!this.isFiniteNumber(item.conflictCount) || item.conflictCount < 0) {
      return false;
    }
    return true;
  }

  private sanitizeRounds(items: AdminRound[]): AdminRound[] {
    const ids: string[] = [];
    const sanitized: AdminRound[] = [];
    items.forEach((item) => {
      if (!this.isValidStoredRound(item)) {
        return;
      }
      const id = item.id.trim();
      if (ids.indexOf(id) >= 0) {
        return;
      }
      ids.push(id);
      const next: AdminRound = {
        id: id,
        name: item.name.trim(),
        status: item.status,
        startTime: item.startTime.trim(),
        endTime: item.endTime.trim(),
        progressPercent: item.progressPercent,
        participantCount: item.participantCount,
        selectionCount: item.selectionCount,
        averageCredit: item.averageCredit,
        conflictCount: item.conflictCount
      };
      sanitized.push(next);
    });
    return sanitized;
  }

  // 状态机：返回从 from 状态可否流转到 to 状态
  private canTransition(from: RoundStatus, to: RoundStatus): boolean {
    if (to === 'running') {
      // 启动：未开始 -> 进行中；暂停 -> 进行中（恢复）
      return from === 'notStarted' || from === 'paused';
    }
    if (to === 'paused') {
      // 暂停：仅进行中可暂停
      return from === 'running';
    }
    if (to === 'ended') {
      // 结束：进行中或暂停可结束
      return from === 'running' || from === 'paused';
    }
    return false;
  }

  private transitionError(to: RoundStatus): string {
    if (to === 'running') {
      return '仅未开始或已暂停的轮次可以启动';
    }
    if (to === 'paused') {
      return '仅进行中的轮次可以暂停';
    }
    return '仅进行中或已暂停的轮次可以结束';
  }

  private withStatus(source: AdminRound, status: RoundStatus): AdminRound {
    const updated: AdminRound = {
      id: source.id,
      name: source.name,
      status: status,
      startTime: source.startTime,
      endTime: source.endTime,
      progressPercent: status === 'ended' ? 100 : source.progressPercent,
      participantCount: source.participantCount,
      selectionCount: source.selectionCount,
      averageCredit: source.averageCredit,
      conflictCount: source.conflictCount
    };
    return updated;
  }

  private async applyTransition(id: string, to: RoundStatus): Promise<AdminRound> {
    if (!AuthorizationService.hasAdminPermission('selection.manage', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    if (AppConfig.useRemote) {
      // \u8054\u673a\u6a21\u5f0f\uff1a\u72b6\u6001\u6d41\u8f6c\u7531\u540e\u7aef\u6743\u5a01\u6821\u9a8c\u5e76\u843d\u5e93\uff08\u7ed3\u675f/\u6682\u505c\u5373\u5168\u5c40\u5173\u95ed\u9009\u8bfe\uff09
      const remote = await RemoteApi.adminSetRoundStatus(id, to);
      return this.delayCopy<AdminRound>(this.liteToRound(remote));
    }
    const items = await this.getRoundItems();
    const target = items.find((item) => item.id === id);
    if (!target) {
      return this.reject('选课轮次不存在', 'notFound');
    }
    if (!this.canTransition(target.status, to)) {
      return this.reject(this.transitionError(to));
    }
    const updated = this.withStatus(target, to);
    const next = items.map((item) => item.id === id ? updated : item);
    await this.saveRounds(next);
    return this.delayCopy<AdminRound>(updated);
  }

  // 远程轮次统计 → 本地 AdminRound（参与人数/选课数/均学分由后端实时聚合）
  private remoteToRound(r: RemoteAdminRound): AdminRound {
    const round: AdminRound = {
      id: r.id,
      name: r.name,
      status: r.status as RoundStatus,
      startTime: r.startTime,
      endTime: r.endTime,
      progressPercent: r.progressPercent,
      participantCount: r.participantCount,
      selectionCount: r.selectionCount,
      averageCredit: r.averageCredit,
      conflictCount: r.conflictCount
    };
    return round;
  }

  // 轮次写操作回显 → AdminRound（聚合统计字段补零；页面提交后会整页重载真实统计）
  private liteToRound(r: RemoteRoundLite): AdminRound {
    const round: AdminRound = {
      id: r.id,
      name: r.name,
      status: r.status as RoundStatus,
      startTime: r.startTime,
      endTime: r.endTime,
      progressPercent: r.status === 'ended' ? 100 : 0,
      participantCount: 0,
      selectionCount: 0,
      averageCredit: 0,
      conflictCount: 0
    };
    return round;
  }

  async getRounds(): Promise<AdminRound[]> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminSelectionStats();
        return this.delayCopy<AdminRound[]>(remote.map((r) => this.remoteToRound(r)));
      } catch (e) {
        // 远程失败回退本地轮次数据
      }
    }
    const items = await this.getRoundItems();
    return this.delayCopy<AdminRound[]>(items);
  }

  // 当前进行中的选课轮次（供学生端选课门禁与轮次展示共享同一事实来源）
  async getActiveRound(): Promise<AdminRound | undefined> {
    if (AppConfig.useRemote) {
      try {
        const remote = await RemoteApi.adminSelectionStats();
        const running = remote.find((r) => r.status === 'running');
        return running ? this.remoteToRound(running) : undefined;
      } catch (e) {
        // 远程失败回退本地
      }
    }
    const items = await this.getRoundItems();
    return items.find((item) => item.status === 'running');
  }

  async getConflicts(roundId: string): Promise<RoundConflict[]> {
    const list = mockRoundConflicts.filter((c) => c.roundId === roundId);
    return this.delayCopy<RoundConflict[]>(list);
  }

  async startRound(id: string): Promise<AdminRound> {
    return this.applyTransition(id, 'running');
  }

  async pauseRound(id: string): Promise<AdminRound> {
    return this.applyTransition(id, 'paused');
  }

  async endRound(id: string): Promise<AdminRound> {
    return this.applyTransition(id, 'ended');
  }

  async updateRoundTime(payload: RoundTimePayload): Promise<AdminRound> {
    if (!AuthorizationService.hasAdminPermission('selection.manage', 'update')) {
      return this.reject('\u65e0\u6743\u9650\u64cd\u4f5c', 'unauthorized');
    }
    const start = payload.startTime.trim();
    const end = payload.endTime.trim();
    if (!this.isValidTime(start) || !this.isValidTime(end)) {
      return this.reject('起止时间需形如 2026-05-20 09:00');
    }
    if (start >= end) {
      return this.reject('开始时间必须早于结束时间');
    }
    if (AppConfig.useRemote) {
      // 联机模式：时间编辑由后端权威校验并落库
      const remote = await RemoteApi.adminSetRoundTime(payload.id, start, end);
      return this.delayCopy<AdminRound>(this.liteToRound(remote));
    }
    const items = await this.getRoundItems();
    const target = items.find((item) => item.id === payload.id);
    if (!target) {
      return this.reject('选课轮次不存在', 'notFound');
    }
    if (target.status === 'ended') {
      return this.reject('已结束的轮次不能修改起止时间');
    }
    const updated: AdminRound = {
      id: target.id,
      name: target.name,
      status: target.status,
      startTime: start,
      endTime: end,
      progressPercent: target.progressPercent,
      participantCount: target.participantCount,
      selectionCount: target.selectionCount,
      averageCredit: target.averageCredit,
      conflictCount: target.conflictCount
    };
    const next = items.map((item) => item.id === payload.id ? updated : item);
    await this.saveRounds(next);
    return this.delayCopy<AdminRound>(updated);
  }
}
