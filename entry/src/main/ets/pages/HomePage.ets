// 首页 · 工作台 Home / Workbench
import { ElysiaTheme } from '../common/Theme';
import {
  Monogram, RoseIcon, Sparkle, RoseDivider,
  Pill, GlowCard
} from '../common/Components';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { StudentTabBar } from '../common/widgets/TabBars';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes, NavigateOptions } from '../app/AppRoute';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { HomeSummary, QuickEntry, DownloadFile, RecentLogin, TermInfo } from '../models/Home';
import { ScheduleItem } from '../models/Course';
import { Notice } from '../models/Notice';
import { UserProfile } from '../models/User';
import { DateUtils } from '../common/utils/DateUtils';

@Entry
@Component
struct HomePage {
  @State summary?: HomeSummary = undefined;
  @State profile?: UserProfile = undefined;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State query: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    const repo = ProfileRepository.get();
    Promise.all([repo.getHomeSummary(), repo.getProfile()])
      .then((res: [HomeSummary, UserProfile]) => {
        this.summary = res[0];
        this.profile = res[1];
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]]
        })

      Column() {
        if (this.loading) {
          Blank().height(80)
          LoadingState({ tip: '正在加载工作台...' })
        } else if (this.errorMsg.length > 0) {
          Blank().height(80)
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.summary !== undefined && this.profile !== undefined) {
          Scroll() {
            Column() {
              this.WelcomeBlock(this.profile!, this.summary!.unreadNoticeCount)
              this.HeroTerm(this.summary!.term)
              RoseDivider({ label: 'quick entrance · 快捷入口' })
              this.QuickGrid(this.summary!.quickEntries)
              this.TodaySection(this.summary!.todayCourses)
              this.NoticeSection(this.summary!.noticeSummary)
              this.FilesSection(this.summary!.files)
              if (this.summary!.recentLogin !== undefined) {
                this.RecentLoginCard(this.summary!.recentLogin!)
              }
              Blank().height(100)
            }
          }
          .scrollBar(BarState.Off)
          .width('100%').layoutWeight(1)
        }
      }
      .width('100%').height('100%')

      Column() {
        Blank().layoutWeight(1)
        StudentTabBar({
          active: 'home',
          onTap: (id: string, route: string) => {
            if (id !== 'home') AppRoute.go(route, { replace: true });
          }
        })
      }.width('100%').height('100%')
    }
    .width('100%').height('100%')
  }

  @Builder WelcomeBlock(p: UserProfile, unread: number) {
    Column() {
      Blank().height(40)
      Row() {
        Monogram({ iconSize: 44 })
        Column() {
          Text('Bonjour ✦').fontSize(11).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
          Text(`${p.name} · ${p.studentId}`)
            .fontSize(17).fontStyle(FontStyle.Italic)
            .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
            .margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 10 })
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.TopEnd }) {
          Button({ type: ButtonType.Circle }) { AppIcon({ name: 'bell', iconSize: 16 }) }
            .width(34).height(34).backgroundColor('#A6FFFFFF')
            .border({ width: 1, color: '#99FFB3CE' })
            .onClick(() => AppRoute.go(Routes.Notices))
          if (unread > 0) {
            Text(unread > 9 ? '9+' : `${unread}`)
              .fontSize(9).fontColor(Color.White).fontWeight(FontWeight.Bold)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(8)
              .margin({ top: -4, right: -4 })
          }
        }
      }
      .width('100%').padding({ left: 18, right: 18, top: 12 })

      Row() {
        AppIcon({ name: 'search', iconSize: 16, mLeft: 14 })
        TextInput({ placeholder: '搜索课程 · 通知 · 文件', text: this.query })
          .height(40).fontSize(12)
          .backgroundColor(Color.Transparent)
          .placeholderColor(ElysiaTheme.INK_MUTE)
          .fontColor(ElysiaTheme.INK)
          .layoutWeight(1)
          .onChange((v: string) => { this.query = v; })
      }
      .width('100%').margin({ left: 16, right: 16, top: 14 })
      .backgroundColor('#B3FFFFFF').borderRadius(14)
      .border({ width: 1, color: '#80FFB3CE' })
    }.width('100%')
  }

  @Builder HeroTerm(term: TermInfo) {
    Column() {
      Text(`${term.academicYear} · ${term.semester.toUpperCase()}`)
        .fontSize(10).fontColor(ElysiaTheme.ROSE_700).letterSpacing(4)
      Row() {
        Text(`W ${term.weekIndex < 10 ? '0' + term.weekIndex : term.weekIndex}`)
          .fontSize(46).fontStyle(FontStyle.Italic)
          .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
        Text(`  第 ${term.weekIndex} 教学周`)
          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      }.alignItems(VerticalAlign.Bottom).margin({ top: 2 })
      Row({ space: 5 }) {
        ForEach(['一', '二', '三', '四', '五', '六', '日'], (day: string, i?: number) => {
          Column() {
            Text(day).fontSize(9)
              .fontColor(this.isToday(i ?? 0) ? Color.White : ElysiaTheme.ROSE_700)
              .opacity(0.85)
            Text(term.weekDates[i ?? 0] ?? '')
              .fontSize(11).fontStyle(FontStyle.Italic)
              .fontColor(this.isToday(i ?? 0) ? Color.White : ElysiaTheme.ROSE_700)
              .fontFamily(ElysiaTheme.FONT_DISPLAY).margin({ top: 2 })
          }
          .layoutWeight(1).padding({ top: 6, bottom: 6 }).borderRadius(10)
          .linearGradient(this.isToday(i ?? 0) ? {
            angle: 135, colors: [[ElysiaTheme.ROSE_500, 0], ['#E08AB8', 1]]
          } : { angle: 0, colors: [['#8CFFFFFF', 0], ['#8CFFFFFF', 1]] })
        }, (day: string) => day)
      }.width('100%').margin({ top: 14 })
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .padding(18).margin({ left: 16, right: 16, top: 12 })
    .borderRadius(24)
    .linearGradient({
      angle: 135,
      colors: [[ElysiaTheme.ROSE_200, 0], ['#FFE0E9', 0.4], [ElysiaTheme.LAV_200, 1]]
    })
    .shadow({ radius: 28, color: '#80F2709C', offsetX: 0, offsetY: 10 })
  }

  @Builder QuickGrid(entries: QuickEntry[]) {
    Grid() {
      ForEach(entries, (q: QuickEntry) => {
        GridItem() {
          Column() {
            Stack() {
              AppIcon({ name: q.icon, iconSize: 26 })
            }
            .width(50).height(50).borderRadius(16)
            .linearGradient({ angle: 135, colors: [[Color.White, 0], [ElysiaTheme.ROSE_100, 1]] })
            .border({ width: 1, color: '#80FFB3CE' })
            .shadow({ radius: 10, color: '#59F2709C', offsetX: 0, offsetY: 4 })
            Text(q.label).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 6 })
          }
          .onClick(() => { if (q.route.length > 0) AppRoute.go(q.route); })
        }
      }, (q: QuickEntry) => q.key)
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .columnsGap(10).rowsGap(14)
    .padding({ left: 16, right: 16, top: 4 })
    .height(160)
  }

  @Builder TodaySection(courses: ScheduleItem[]) {
    Row() {
      Column() {
        Text("Today's Lessons").fontSize(18).fontStyle(FontStyle.Italic)
          .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
        Text(`${DateUtils.today()} · 共 ${courses.length} 节`)
          .fontSize(10).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
      }.alignItems(HorizontalAlign.Start)
      Blank().layoutWeight(1)
      Text('view all ›').fontSize(10).fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
        .onClick(() => AppRoute.go(Routes.Today))
    }.width('100%').padding({ left: 20, right: 20, top: 18 })

    if (courses.length === 0) {
      Column() {
        AppIcon({ name: 'petal', iconSize: 30, dim: true })
        Text('今日无课 · 享受片刻闲暇')
          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 6 })
      }
      .width('100%').padding(30).margin({ left: 16, right: 16, top: 10 })
      .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
      .border({ width: 1, color: '#66FFB3CE' })
    } else {
      Column({ space: 10 }) {
        ForEach(courses, (c: ScheduleItem) => {
          this.LessonCard(c)
        }, (c: ScheduleItem) => c.id)
      }.padding({ left: 16, right: 16, top: 10 })
    }
  }

  @Builder LessonCard(c: ScheduleItem) {
    Row() {
      Column() {
        Text(`${c.periodStart}-${c.periodEnd} 节`).fontSize(13).fontStyle(FontStyle.Italic)
          .fontColor(this.hueText(c.courseType)).fontFamily(ElysiaTheme.FONT_DISPLAY)
        Text(`${c.startTime}`).fontSize(9).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
      }
      .width(70).padding({ top: 10, bottom: 10 }).borderRadius(14)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({ angle: 180, colors: this.hueBg(c.courseType) })

      Column() {
        Text(c.courseName).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Row() {
          AppIcon({ name: 'pin', iconSize: 12 })
          Text(`${c.classroom} · ${c.teacher}`)
            .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ left: 4 })
        }.margin({ top: 4 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 12, right: 12 })

      Pill({ text: c.courseType })
    }
    .width('100%').padding(12)
    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
    .border({ width: 1, color: '#66FFB3CE' })
    .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      let p: Record<string, Object> = { 'id': c.courseId };
      let opts: NavigateOptions = { params: p };
      AppRoute.go(Routes.CourseDetail, opts);
    })
  }

  @Builder NoticeSection(items: Notice[]) {
    Row() {
      Text('From the Hall').fontSize(18).fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Blank().layoutWeight(1)
      Text('more ›').fontSize(10).fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
        .onClick(() => AppRoute.go(Routes.Notices))
    }.width('100%').padding({ left: 20, right: 20, top: 18 })

    Column() {
      GlowCard() {
        ForEach(items, (n: Notice, i?: number) => {
          Row() {
            Pill({ text: n.publisher })
            Text(n.title).fontSize(12).fontColor(ElysiaTheme.INK)
              .layoutWeight(1).margin({ left: 10, right: 10 }).maxLines(1)
            Text(n.publishedAt.slice(5, 10)).fontSize(10).fontStyle(FontStyle.Italic)
              .fontColor(ElysiaTheme.INK_MUTE).fontFamily(ElysiaTheme.FONT_DISPLAY)
          }
          .width('100%').padding({ top: 8, bottom: 8 })
          .onClick(() => {
            let p: Record<string, Object> = { 'id': n.id };
            let opts: NavigateOptions = { params: p };
            AppRoute.go(Routes.NoticeDetail, opts);
          })
          if (i !== undefined && i < items.length - 1) {
            Divider().strokeWidth(1).color('#80FFB3CE')
          }
        }, (n: Notice) => n.id)
      }
    }.padding({ left: 16, right: 16, top: 8 })
  }

  @Builder FilesSection(files: DownloadFile[]) {
    Row() {
      Text('Files').fontSize(18).fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Blank().layoutWeight(1)
      Text(`${files.length} 项`).fontSize(10).fontColor(ElysiaTheme.INK_SOFT).letterSpacing(2)
    }.width('100%').padding({ left: 20, right: 20, top: 18 })

    Column({ space: 8 }) {
      ForEach(files, (f: DownloadFile) => {
        Row() {
          Text(f.fileType.toUpperCase()).fontSize(9).fontWeight(FontWeight.Bold)
            .fontColor(ElysiaTheme.GOLD_700).padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#FBE6C2').borderRadius(8)
          Column() {
            Text(f.fileName).fontSize(12).fontColor(ElysiaTheme.INK).maxLines(1)
            Text(`${f.updatedAt} · ${this.formatSize(f.fileSize)}`)
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
          AppIcon({ name: 'download', iconSize: 16 })
        }
        .width('100%').padding(12)
        .backgroundColor(ElysiaTheme.SURFACE).borderRadius(16)
        .border({ width: 1, color: '#66FFB3CE' })
      }, (f: DownloadFile) => f.id)
    }.padding({ left: 16, right: 16, top: 8 })
  }

  @Builder RecentLoginCard(rl: RecentLogin) {
    Row() {
      Sparkle({ iconSize: 14 })
      Column() {
        Text('上次登录').fontSize(10).fontColor(ElysiaTheme.INK_MUTE).letterSpacing(2)
        Text(`${rl.loginTime} · ${rl.network}`)
          .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
        Text(rl.region).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
    }
    .width('100%').padding(14).margin({ left: 16, right: 16, top: 18 })
    .backgroundColor('#99FFFFFF').borderRadius(18)
    .border({ width: 1, color: '#66FFB3CE' })
  }

  isToday(idx: number): boolean {
    if (!this.summary) return false;
    const today = new Date();
    const todayLabel = `${(today.getMonth() + 1).toString().padStart(2, '0')}/${today.getDate().toString().padStart(2, '0')}`;
    return this.summary.term.weekDates[idx] === todayLabel;
  }

  hueText(t: string): string {
    if (t === '选修') return '#6F47A8';
    if (t === '公选') return ElysiaTheme.GOLD_700;
    return ElysiaTheme.ROSE_700;
  }

  hueBg(t: string): Array<[string, number]> {
    if (t === '选修') return [['#F1E2FF', 0], [ElysiaTheme.LAV_300, 1]];
    if (t === '公选') return [['#FFF1D6', 0], [ElysiaTheme.GOLD_300, 1]];
    return [['#FFE4EE', 0], [ElysiaTheme.ROSE_200, 1]];
  }

  formatSize(bytes?: number): string {
    if (!bytes) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1048576).toFixed(1)} MB`;
  }
}
