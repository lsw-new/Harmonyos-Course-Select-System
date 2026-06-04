// 校历管理 · Calendar
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput } from '../common/Components';
import { SafeTop } from '../common/widgets/SafeArea';
import { SysConfigRepository } from '../repositories/SysConfigRepository';
import { CalendarEvent, CalendarEventType, CalendarEventPayload } from '../models/SysConfigModels';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import { Toast } from '../common/widgets/Feedback';
import { BreakpointManager } from '../common/widgets/Breakpoint';

@Component
struct AdminCalendarPage {
  @StorageProp('breakpoint') bp: string = 'sm';
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
    AppRoute.showLoading();
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
    if (t === 'exam') return ElysiaTheme.ROSE_ACCENT;
    if (t === 'holiday') return ElysiaTheme.SUCCESS;
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
      Toast.show(this.getUIContext(), '校历事件已新增');
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
      Toast.show(this.getUIContext(), '校历事件已删除');
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '删除失败';
      Toast.show(this.getUIContext(), msg);
    });
  }

  @Builder
  EditorPanel() {
    Scroll() {
      Column({ space: 10 }) {
        Text($r('app.string.admincalendar_new_event'))
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        ElysiaInput({ placeholder: $r('app.string.admincalendar_ph_date'), value: $date, leadingIcon: 'calendar' })
        ElysiaInput({ placeholder: $r('app.string.admincalendar_ph_title'), value: $title, leadingIcon: 'edit' })

        Column({ space: 6 }) {
          Text($r('app.string.admincalendar_event_type')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
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
          Text(this.formError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
        }

        Row({ space: 10 }) {
          GhostButton({ text: $r('app.string.common_cancel'), onTap: () => this.cancelEdit() }).layoutWeight(1)
          PrimaryButton({ text: this.submitting ? $r('app.string.common_saving') : $r('app.string.common_save'), onTap: () => this.saveEvent() }).layoutWeight(1)
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
          Text(`确认删除「${item.title}」`).fontSize(11).fontColor(ElysiaTheme.ROSE_ACCENT).layoutWeight(1)
          Text($r('app.string.common_cancel')).fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#F5F2F4').borderRadius(999).margin({ right: 10 })
            .onClick(() => { this.cancelDelete(); })
          Text($r('app.string.admincalendar_confirm_delete')).fontSize(12).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(ElysiaTheme.ROSE_ACCENT).borderRadius(999)
            .onClick(() => { this.deleteEvent(item); })
        } else {
          Blank().layoutWeight(1)
          Text($r('app.string.admincalendar_delete_btn')).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT)
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
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.admincalendar_title'), subtitle: $r('app.string.admincalendar_subtitle'), onBack: () => AppRoute.back() })

        Row() {
          Text($r('app.string.admincalendar_events')).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
          Text($r('app.string.admincalendar_add')).fontSize(13).fontColor(Color.White).fontWeight(FontWeight.Bold)
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
          EmptyState({ title: $r('app.string.admincalendar_empty'), hint: '点击右上角新增' })
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
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function AdminCalendarPageBuilder() {
  NavDestination() {
    AdminCalendarPage()
  }
  .hideTitleBar(true)
}
