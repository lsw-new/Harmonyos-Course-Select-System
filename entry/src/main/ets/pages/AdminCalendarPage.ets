// 校历管理 · Calendar
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput } from '../common/Components';
import { SafeTop } from '../common/widgets/SafeArea';
import { SysConfigRepository } from '../repositories/SysConfigRepository';
import { CalendarEvent, CalendarEventType, CalendarEventPayload } from '../models/SysConfigModels';
import { AppRoute, Routes } from '../app/AppRoute';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct AdminCalendarPage {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State formError: string = '';
  @State events: CalendarEvent[] = [];
  @State isEditing: boolean = false;
  @State date: string = '';
  @State title: string = '';
  @State type: string = 'term';
  @State pendingDeleteId: string = '';
  // 底部手势条避让（vp）：List 无 TabBar 兜底，需自行留出底部安全区。
  @StorageProp('safeBottom') safeBottom: number = 0;
  private types: string[] = ['term', 'exam', 'holiday', 'selection', 'makeup', 'other'];
  private typeLabels: string[] = ['开学', '考试周', '假期', '选课', '补缓考', '其他'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminCalendar)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    SysConfigRepository.get().getCalendarEvents().then((list: CalendarEvent[]) => {
      list.sort((a, b) => a.date < b.date ? -1 : (a.date > b.date ? 1 : 0));
      this.events = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private typeLabel(t: string): string {
    const idx = this.types.indexOf(t);
    return idx >= 0 ? this.typeLabels[idx] : '其他';
  }

  private typeColor(t: string): string {
    if (t === 'term') return ElysiaTheme.ROSE_600;
    if (t === 'exam') return '#D8546B';
    if (t === 'holiday') return '#7BB07B';
    if (t === 'selection') return ElysiaTheme.LAV_500;
    if (t === 'makeup') return ElysiaTheme.GOLD_700;
    return ElysiaTheme.INK_MUTE;
  }

  private resetForm(): void {
    this.date = '';
    this.title = '';
    this.type = 'term';
    this.formError = '';
  }

  private openCreate(): void {
    this.pendingDeleteId = '';
    this.resetForm();
    this.isEditing = true;
  }

  private cancelEdit(): void {
    this.isEditing = false;
    this.resetForm();
  }

  private saveEvent(): void {
    if (this.submitting) return;
    const payload: CalendarEventPayload = {
      date: this.date.trim(),
      title: this.title.trim(),
      type: this.type as CalendarEventType
    };
    this.submitting = true;
    this.formError = '';
    SysConfigRepository.get().addCalendarEvent(payload).then(() => {
      this.submitting = false;
      promptAction.showToast({ message: '校历事件已新增' });
      this.cancelEdit();
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '保存失败';
    });
  }

  private requestDelete(item: CalendarEvent): void {
    if (this.submitting) return;
    this.pendingDeleteId = item.id;
  }

  private cancelDelete(): void {
    this.pendingDeleteId = '';
  }

  private deleteEvent(item: CalendarEvent): void {
    if (this.submitting) return;
    this.submitting = true;
    SysConfigRepository.get().deleteCalendarEvent(item.id).then(() => {
      this.submitting = false;
      this.pendingDeleteId = '';
      promptAction.showToast({ message: '校历事件已删除' });
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '删除失败';
      promptAction.showToast({ message: msg });
    });
  }

  @Builder
  EditorPanel() {
    Scroll() {
      Column({ space: 10 }) {
        Text('新增校历事件')
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        ElysiaInput({ placeholder: '日期，如：2026-02-23', value: $date, leadingIcon: 'calendar' })
        ElysiaInput({ placeholder: '事件标题', value: $title, leadingIcon: 'edit' })

        Column({ space: 6 }) {
          Text('事件类型').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
          Row({ space: 8 }) {
            ForEach(this.typeLabels, (label: string, idx: number) => {
              Text(label).fontSize(12)
                .fontColor(this.type === this.types[idx] ? Color.White : ElysiaTheme.ROSE_700)
                .padding({ left: 13, right: 13, top: 6, bottom: 6 })
                .backgroundColor(this.type === this.types[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                .borderRadius(999)
                .onClick(() => { this.type = this.types[idx]; })
            }, (label: string, idx: number) => `cal-type-${idx}`)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)

        if (this.formError.length > 0) {
          Text(this.formError).fontSize(12).fontColor('#D8546B')
        }

        Row({ space: 10 }) {
          GhostButton({ text: '取消', onTap: () => this.cancelEdit() }).layoutWeight(1)
          PrimaryButton({ text: this.submitting ? '保存中...' : '保存', onTap: () => this.saveEvent() }).layoutWeight(1)
        }
      }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    }.height(290).padding({ left: 16, right: 16, top: 10 }).scrollBar(BarState.Off)
  }

  @Builder
  EventCard(item: CalendarEvent) {
    Column({ space: 8 }) {
      Row() {
        Text(item.title).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
        Pill({ text: this.typeLabel(item.type), color: this.typeColor(item.type), bg: '#FFF6FA' })
      }.width('100%')
      Text(item.date).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      Row() {
        if (this.pendingDeleteId === item.id) {
          Text(`确认删除「${item.title}」`).fontSize(11).fontColor('#D8546B').layoutWeight(1)
          Text('取消').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#F5F2F4').borderRadius(999).margin({ right: 10 })
            .onClick(() => { this.cancelDelete(); })
          Text('确认删除').fontSize(12).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#D8546B').borderRadius(999)
            .onClick(() => { this.deleteEvent(item); })
        } else {
          Blank().layoutWeight(1)
          Text('删除').fontSize(12).fontColor('#D8546B')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#FFF0F3').borderRadius(999)
            .onClick(() => { this.requestDelete(item); })
        }
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: 'Calendar', subtitle: '校 历 管 理', onBack: () => AppRoute.back() })

        Row() {
          Text('校历事件').fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
          Text('新增').fontSize(13).fontColor(Color.White).fontWeight(FontWeight.Bold)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
            .onClick(() => { this.openCreate(); })
        }.width('100%').padding({ left: 16, right: 16, top: 6 })

        if (this.isEditing) {
          this.EditorPanel()
        }

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.events.length === 0) {
          EmptyState({ title: '暂无校历事件', hint: '点击右上角新增' })
        } else {
          List() {
            ForEach(this.events, (item: CalendarEvent) => {
              ListItem() {
                this.EventCard(item)
              }.margin({ bottom: 8 })
            }, (item: CalendarEvent) => item.id)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10, bottom: this.safeBottom + 24 })
        }
      }
    }.width('100%').height('100%')
  }
}
