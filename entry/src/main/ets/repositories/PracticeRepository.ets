// 实践项目仓储 · Practice
// 项目数据来自 mock 种子，报名状态持久化到本地（仅记录已报名的项目 id）。
// signedUp 在读取时由持久化记录派生，slotsTaken 反映种子 + 本机报名。

import { BaseRepository } from './BaseRepository';
import {
  PracticeProject,
  PracticeProjectDetail,
  PracticeCategory,
  PracticeSignupRecord
} from '../models/PracticeModels';
import { mockPracticeDetails } from '../mock/mockPractice';
import { LocalDataStore } from '../common/storage/LocalDataStore';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AppConfig } from '../app/AppConfig';
import { RemoteApi, RemotePractice } from '../common/remote/RemoteApi';

const KEY_SIGNUPS = 'local.practiceSignups.v1';
const CATEGORIES: string[] = ['internship', 'research', 'social', 'volunteer'];

export class PracticeRepository extends BaseRepository {
  private static _instance?: PracticeRepository;
  static get(): PracticeRepository {
    if (!PracticeRepository._instance) {
      PracticeRepository._instance = new PracticeRepository();
    }
    return PracticeRepository._instance;
  }

  // 已报名的项目 id 集合（持久化）。
  private signups: string[] = [];
  private isLoaded: boolean = false;

  private isAllowedCategory(value: string): boolean {
    return CATEGORIES.indexOf(value) >= 0;
  }

  // 校验并去重持久化记录，丢弃不指向已知项目的脏数据。
  private sanitizeSignups(items: PracticeSignupRecord[]): string[] {
    const result: string[] = [];
    items.forEach((item) => {
      if (!item || typeof item !== 'object' || typeof item.id !== 'string') {
        return;
      }
      const id = item.id.trim();
      if (id.length === 0 || result.indexOf(id) >= 0) {
        return;
      }
      const known = mockPracticeDetails.find((d) => d.id === id);
      if (!known) {
        return;
      }
      result.push(id);
    });
    return result;
  }

  private async getSignups(): Promise<string[]> {
    if (!this.isLoaded) {
      const stored = await LocalDataStore.loadArray<PracticeSignupRecord>(KEY_SIGNUPS, []);
      this.signups = this.sanitizeSignups(stored);
      this.isLoaded = true;
    }
    return this.signups;
  }

  private async saveSignups(next: string[]): Promise<void> {
    this.signups = next;
    this.isLoaded = true;
    const records: PracticeSignupRecord[] = next.map((id) => {
      const record: PracticeSignupRecord = { id };
      return record;
    });
    await LocalDataStore.saveArray<PracticeSignupRecord>(KEY_SIGNUPS, records);
  }

  // 由种子详情 + 报名集合，投影出携带派生状态的详情。
  private projectDetailFrom(seed: PracticeProjectDetail, signedUp: boolean): PracticeProjectDetail {
    const slotsTaken = signedUp ? seed.slotsTaken + 1 : seed.slotsTaken;
    const detail: PracticeProjectDetail = {
      id: seed.id,
      title: seed.title,
      org: seed.org,
      category: seed.category,
      credits: seed.credits,
      period: seed.period,
      location: seed.location,
      mentor: seed.mentor,
      slotsTotal: seed.slotsTotal,
      slotsTaken: Math.min(slotsTaken, seed.slotsTotal),
      signedUp,
      description: seed.description,
      requirements: seed.requirements.map((r) => r)
    };
    return detail;
  }

  private toListItem(detail: PracticeProjectDetail): PracticeProject {
    const project: PracticeProject = {
      id: detail.id,
      title: detail.title,
      org: detail.org,
      category: detail.category,
      credits: detail.credits,
      period: detail.period,
      slotsTotal: detail.slotsTotal,
      slotsTaken: detail.slotsTaken,
      signedUp: detail.signedUp
    };
    return project;
  }

  private remoteToProject(p: RemotePractice): PracticeProject {
    const item: PracticeProject = {
      id: p.id,
      title: p.title,
      org: p.org,
      category: p.category as PracticeCategory,
      credits: p.credits,
      period: p.period,
      slotsTotal: p.slotsTotal,
      slotsTaken: p.slotsTaken,
      signedUp: p.signedUp
    };
    return item;
  }

  private remoteToDetail(p: RemotePractice): PracticeProjectDetail {
    const item: PracticeProjectDetail = {
      id: p.id,
      title: p.title,
      org: p.org,
      category: p.category as PracticeCategory,
      credits: p.credits,
      period: p.period,
      location: p.location,
      mentor: p.mentor,
      slotsTotal: p.slotsTotal,
      slotsTaken: p.slotsTaken,
      signedUp: p.signedUp,
      description: p.description,
      requirements: p.requirements
    };
    return item;
  }

  async getProjects(category?: PracticeCategory): Promise<PracticeProject[]> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.listPractice(student.studentId, category);
          return this.delayCopy<PracticeProject[]>(remote.map((p) => this.remoteToProject(p)));
        } catch (e) {
          // 远程失败回退本地
        }
      }
    }
    const signups = await this.getSignups();
    let seeds = mockPracticeDetails;
    if (category !== undefined && this.isAllowedCategory(category)) {
      seeds = seeds.filter((d) => d.category === category);
    }
    const list: PracticeProject[] = seeds.map((seed) => {
      const signedUp = signups.indexOf(seed.id) >= 0;
      return this.toListItem(this.projectDetailFrom(seed, signedUp));
    });
    return this.delayCopy<PracticeProject[]>(list);
  }

  async getDetail(id: string): Promise<PracticeProjectDetail> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.practiceDetail(student.studentId, id);
          return this.delayCopy<PracticeProjectDetail>(this.remoteToDetail(remote));
        } catch (e) {
          // 远程失败回退本地
        }
      }
    }
    const seed = mockPracticeDetails.find((d) => d.id === id);
    if (!seed) {
      return this.reject('实践项目不存在', 'notFound');
    }
    const signups = await this.getSignups();
    const signedUp = signups.indexOf(id) >= 0;
    return this.delayCopy<PracticeProjectDetail>(this.projectDetailFrom(seed, signedUp));
  }

  async signUp(id: string): Promise<PracticeProject> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.practiceSignup(student.studentId, id);
          return this.delay<PracticeProject>(this.remoteToProject(remote));
        } catch (e) {
          return this.reject((e instanceof Error) ? e.message : String(e));
        }
      }
    }
    const seed = mockPracticeDetails.find((d) => d.id === id);
    if (!seed) {
      return this.reject('实践项目不存在', 'notFound');
    }
    const signups = await this.getSignups();
    if (signups.indexOf(id) >= 0) {
      return this.reject('您已报名该项目');
    }
    if (seed.slotsTaken >= seed.slotsTotal) {
      return this.reject('该项目名额已满');
    }
    const next = signups.map((x) => x);
    next.push(id);
    await this.saveSignups(next);
    return this.delayCopy<PracticeProject>(this.toListItem(this.projectDetailFrom(seed, true)));
  }

  async cancelSignUp(id: string): Promise<PracticeProject> {
    if (AppConfig.useRemote) {
      const student = SessionStorage.get().getStudent();
      if (student) {
        try {
          const remote = await RemoteApi.practiceCancel(student.studentId, id);
          return this.delay<PracticeProject>(this.remoteToProject(remote));
        } catch (e) {
          return this.reject((e instanceof Error) ? e.message : String(e));
        }
      }
    }
    const seed = mockPracticeDetails.find((d) => d.id === id);
    if (!seed) {
      return this.reject('实践项目不存在', 'notFound');
    }
    const signups = await this.getSignups();
    if (signups.indexOf(id) < 0) {
      return this.reject('您尚未报名该项目');
    }
    const next = signups.filter((x) => x !== id);
    await this.saveSignups(next);
    return this.delayCopy<PracticeProject>(this.toListItem(this.projectDetailFrom(seed, false)));
  }
}
