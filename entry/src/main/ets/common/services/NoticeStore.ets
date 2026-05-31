import { Notice } from '../../models/Notice';
import { NoticeDraft } from '../../models/Admin';
import { AppDatabase } from '../storage/AppDatabase';
import { LocalDataStore } from '../storage/LocalDataStore';
import { SessionStorage } from '../storage/SessionStorage';

const KEY_LOCAL_NOTICES = 'local.notices.v1';
const KEY_NOTICE_READS = 'local.noticeReads.v1';

interface NoticeReadMark {
  noticeId: string;
  ownerId: string;
  readAt: string;
}

export class NoticeStore {
  static async publish(draft: NoticeDraft): Promise<Notice> {
    const now = new Date().toISOString();
    const admin = SessionStorage.get().getAdmin();
    const notice: Notice = {
      id: `nt-${Date.now()}`,
      title: draft.title.trim(),
      publisher: draft.publisher.trim() || (admin ? admin.name : ''),
      publishedAt: draft.publishTime ? draft.publishTime : now,
      summary: NoticeStore.toSummary(draft.content),
      content: draft.content.trim(),
      isRead: false,
      category: draft.category,
      attachments: []
    };
    if (AppDatabase.isReady()) {
      await NoticeStore.insertNoticeToRdb(notice, draft);
      return notice;
    }
    const localItems = await NoticeStore.loadLocalNotices();
    await LocalDataStore.saveArray<Notice>(KEY_LOCAL_NOTICES, [notice].concat(localItems));
    return notice;
  }

  static async list(seed: Notice[], category?: string): Promise<Notice[]> {
    if (AppDatabase.isReady()) {
      const rdbItems = await NoticeStore.listFromRdb(category);
      let items = NoticeStore.merge(rdbItems, seed);
      items = await NoticeStore.applyReadMarks(items);
      if (category && category !== '全部') {
        items = items.filter((item) => item.category === category);
      }
      return items;
    }
    let items = NoticeStore.merge(await NoticeStore.loadLocalNotices(), seed);
    items = await NoticeStore.applyReadMarks(items);
    if (category && category !== '全部') {
      items = items.filter((item) => item.category === category);
    }
    return items;
  }

  static async detail(seed: Notice[], id: string): Promise<Notice | undefined> {
    const items = await NoticeStore.list(seed);
    return items.find((item) => item.id === id);
  }

  static async markRead(id: string): Promise<void> {
    const ownerId = NoticeStore.getOwnerId();
    if (AppDatabase.isReady()) {
      const exists = await NoticeStore.noticeExistsInRdb(id);
      if (!exists) {
        await NoticeStore.markLocalRead(id, ownerId);
        return;
      }
      if (!SessionStorage.get().getStudent()) {
        await NoticeStore.markLocalRead(id, ownerId);
        return;
      }
      await NoticeStore.ensureStudentProfileForRead();
      await AppDatabase.execute(
        `INSERT OR REPLACE INTO notice_reads (notice_id, student_id, read_at) VALUES (${AppDatabase.sqlText(id)}, ${AppDatabase.sqlText(ownerId)}, CURRENT_TIMESTAMP)`
      );
      return;
    }
    const reads = await LocalDataStore.loadArray<NoticeReadMark>(KEY_NOTICE_READS, []);
    const exists = reads.some((item) => item.noticeId === id && item.ownerId === ownerId);
    if (!exists) {
      await NoticeStore.markLocalRead(id, ownerId);
    }

    const localItems = await NoticeStore.loadLocalNotices();
    const next = localItems.map((item) => {
      if (item.id !== id) {
        return item;
      }
      const updated: Notice = {
        id: item.id,
        title: item.title,
        publisher: item.publisher,
        publishedAt: item.publishedAt,
        summary: item.summary,
        content: item.content,
        isRead: true,
        category: item.category,
        attachments: item.attachments
      };
      return updated;
    });
    await LocalDataStore.saveArray<Notice>(KEY_LOCAL_NOTICES, next);
  }

  private static async loadLocalNotices(): Promise<Notice[]> {
    return LocalDataStore.loadArray<Notice>(KEY_LOCAL_NOTICES, []);
  }

  private static async markLocalRead(id: string, ownerId: string): Promise<void> {
    const reads = await LocalDataStore.loadArray<NoticeReadMark>(KEY_NOTICE_READS, []);
    const exists = reads.some((item) => item.noticeId === id && item.ownerId === ownerId);
    if (!exists) {
      const mark: NoticeReadMark = {
        noticeId: id,
        ownerId: ownerId,
        readAt: new Date().toISOString()
      };
      await LocalDataStore.saveArray<NoticeReadMark>(KEY_NOTICE_READS, [mark].concat(reads));
    }
  }

  private static async ensureStudentProfileForRead(): Promise<void> {
    const student = SessionStorage.get().getStudent();
    if (!student) {
      return;
    }
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO student_profiles (
        student_id, account_id, name, gender, college, major, class_name, grade, phone, email,
        address, emergency_contact, avatar_url, bio, status, updated_at
      ) VALUES (
        ${AppDatabase.sqlText(student.studentId)},
        NULL,
        ${AppDatabase.sqlText(student.name)},
        NULL,
        ${AppDatabase.sqlText(student.college)},
        ${AppDatabase.sqlText(student.major)},
        ${AppDatabase.sqlText(student.className)},
        ${AppDatabase.sqlText(student.grade)},
        ${AppDatabase.sqlNullableText(student.phone)},
        ${AppDatabase.sqlNullableText(student.email)},
        ${AppDatabase.sqlNullableText(student.address)},
        ${AppDatabase.sqlNullableText(student.emergencyContact)},
        ${AppDatabase.sqlNullableText(student.avatarUrl)},
        ${AppDatabase.sqlNullableText(student.bio)},
        'active',
        CURRENT_TIMESTAMP
      )`
    );
  }

  private static async noticeExistsInRdb(id: string): Promise<boolean> {
    const resultSet = await AppDatabase.query(
      `SELECT notice_id FROM notices WHERE notice_id = ${AppDatabase.sqlText(id)} LIMIT 1`
    );
    try {
      return resultSet.goToNextRow();
    } finally {
      resultSet.close();
    }
  }

  private static async insertNoticeToRdb(notice: Notice, draft: NoticeDraft): Promise<void> {
    const admin = SessionStorage.get().getAdmin();
    const publisherId = admin ? admin.adminId : '';
    await AppDatabase.execute(
      `INSERT OR REPLACE INTO notices (
        notice_id, title, content, summary, publisher_id, publisher_name, category, urgency,
        receiver_type, receiver_scope_json, published_at, expire_time, created_at
      ) VALUES (
        ${AppDatabase.sqlText(notice.id)},
        ${AppDatabase.sqlText(notice.title)},
        ${AppDatabase.sqlText(notice.content)},
        ${AppDatabase.sqlText(notice.summary)},
        ${AppDatabase.sqlText(publisherId)},
        ${AppDatabase.sqlText(notice.publisher)},
        ${AppDatabase.sqlText(notice.category)},
        ${AppDatabase.sqlText(draft.urgency)},
        ${AppDatabase.sqlText(draft.receiverType)},
        ${AppDatabase.sqlText(JSON.stringify(draft.receiverScope))},
        ${AppDatabase.sqlText(notice.publishedAt)},
        ${AppDatabase.sqlNullableText(draft.expireTime)},
        CURRENT_TIMESTAMP
      )`
    );
  }

  private static async listFromRdb(category?: string): Promise<Notice[]> {
    const ownerId = NoticeStore.getOwnerId();
    let where = '';
    if (category && category !== '全部') {
      where = `WHERE n.category = ${AppDatabase.sqlText(category)}`;
    }
    const resultSet = await AppDatabase.query(
      `SELECT
        n.notice_id,
        n.title,
        n.publisher_name,
        n.published_at,
        n.summary,
        n.content,
        CASE WHEN nr.notice_id IS NULL THEN 'false' ELSE 'true' END AS is_read,
        n.category
      FROM notices n
      LEFT JOIN notice_reads nr
        ON nr.notice_id = n.notice_id AND nr.student_id = ${AppDatabase.sqlText(ownerId)}
      ${where}
      ORDER BY n.published_at DESC`
    );
    const items: Notice[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const item: Notice = {
          id: resultSet.getString(resultSet.getColumnIndex('notice_id')),
          title: resultSet.getString(resultSet.getColumnIndex('title')),
          publisher: resultSet.getString(resultSet.getColumnIndex('publisher_name')),
          publishedAt: resultSet.getString(resultSet.getColumnIndex('published_at')),
          summary: resultSet.getString(resultSet.getColumnIndex('summary')),
          content: resultSet.getString(resultSet.getColumnIndex('content')),
          isRead: resultSet.getString(resultSet.getColumnIndex('is_read')) === 'true',
          category: resultSet.getString(resultSet.getColumnIndex('category')),
          attachments: []
        };
        items.push(item);
      }
    } finally {
      resultSet.close();
    }
    return items;
  }

  private static async applyReadMarks(items: Notice[]): Promise<Notice[]> {
    const ownerId = NoticeStore.getOwnerId();
    const reads = await LocalDataStore.loadArray<NoticeReadMark>(KEY_NOTICE_READS, []);
    return items.map((item) => {
      const isRead = item.isRead || reads.some((mark) => mark.noticeId === item.id && mark.ownerId === ownerId);
      const updated: Notice = {
        id: item.id,
        title: item.title,
        publisher: item.publisher,
        publishedAt: item.publishedAt,
        summary: item.summary,
        content: item.content,
        isRead: isRead,
        category: item.category,
        attachments: item.attachments
      };
      return updated;
    });
  }

  private static merge(localItems: Notice[], seedItems: Notice[]): Notice[] {
    const result: Notice[] = JSON.parse(JSON.stringify(localItems)) as Notice[];
    seedItems.forEach((item) => {
      const exists = result.some((cur) => cur.id === item.id);
      if (!exists) {
        result.push(item);
      }
    });
    return result;
  }

  private static getOwnerId(): string {
    const student = SessionStorage.get().getStudent();
    if (student) {
      return student.studentId;
    }
    const admin = SessionStorage.get().getAdmin();
    if (admin) {
      return admin.adminId;
    }
    return 'anonymous';
  }

  private static toSummary(content: string): string {
    const text = content.trim();
    if (text.length <= 60) {
      return text;
    }
    return `${text.substring(0, 60)}...`;
  }
}
