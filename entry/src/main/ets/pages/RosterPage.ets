// 学籍信息 · Roster
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill } from '../common/Components';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { AcademicRepository } from '../repositories/AcademicRepository';
import { StudentRecord } from '../models/Academic';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Entry
@Component
struct RosterPage {
  @State record?: StudentRecord = undefined;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Roster)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    AcademicRepository.get().getStudentRecord()
      .then((res: StudentRecord) => {
        this.record = res;
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  pageTransition() {
    PageTransitionEnter({ duration: 280, curve: Curve.Friction })
      .slide(SlideEffect.Right)
      .opacity(0.4)
    PageTransitionExit({ duration: 240, curve: Curve.Friction })
      .slide(SlideEffect.Left)
      .opacity(0.4)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: '学籍信息', subtitle: '学 籍 信 息', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({ tip: '正在加载学籍信息...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.record !== undefined) {
          Scroll() {
            Column() {
              // Profile header card
              Row() {
                Stack() {
                  Text('照片').fontSize(9).fontColor(ElysiaTheme.ROSE_700).letterSpacing(2).fontFamily('monospace')
                }
                .width(84).height(108).borderRadius(12).backgroundColor(ElysiaTheme.ROSE_200)

                Column() {
                  Text(`${this.record!.name} · 同学`)
                    .fontSize(22).fontStyle(FontStyle.Italic)
                    .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  Text(`${this.record!.college} · ${this.record!.major}`)
                    .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 4 })
                  Text(`${this.record!.className} · ${this.record!.studentId}`)
                    .fontSize(10).fontStyle(FontStyle.Italic)
                    .fontColor(ElysiaTheme.INK_MUTE).fontFamily(ElysiaTheme.FONT_DISPLAY).margin({ top: 2 })
                  Row({ space: 6 }) {
                    Pill({ text: this.record!.isRegistered ? '在籍' : '非在籍' })
                    Pill({
                      text: this.record!.isAtSchool ? '在校' : '离校',
                      bg: this.record!.isAtSchool ? '#D8F0D8' : '#FFE4E4',
                      color: this.record!.isAtSchool ? '#3F7A4A' : '#A83030'
                    })
                  }.margin({ top: 8 })
                }.alignItems(HorizontalAlign.Start).margin({ left: 14 }).layoutWeight(1)
              }
              .width('100%').padding(18).borderRadius(22)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })

              // Detail rows
              Column() {
                ForEach(
                  [
                    ['学号', this.record!.studentId],
                    ['姓名', this.record!.name],
                    ['英文名', this.record!.englishName ?? '—'],
                    ['性别', this.record!.gender],
                    ['年级', this.record!.grade],
                    ['学制', this.record!.schoolingLength],
                    ['学历', this.record!.educationLevel],
                    ['学生类别', this.record!.studentCategory],
                    ['专业', this.record!.major],
                    ['方向', this.record!.direction ?? '—'],
                    ['学院', this.record!.college],
                    ['班级', this.record!.className],
                    ['入校日期', this.record!.entranceDate],
                    ['毕业日期', this.record!.graduationDate ?? '—'],
                    ['学习方式', this.record!.studyMode],
                    ['注册状态', this.record!.isRegistered ? '在籍' : '非在籍'],
                    ['在校状态', this.record!.isAtSchool ? '在校' : '离校'],
                    ['所属校区', this.record!.campus],
                    ['学籍状态', this.record!.recordStatus],
                    ['生效日期', this.record!.effectiveDate],
                    ['备注', this.record!.remark ?? '—']
                  ] as Array<[string, string]>,
                  (kv: [string, string], i?: number) => {
                    Row() {
                      Text(kv[0]).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
                      Text(kv[1]).fontSize(12).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK)
                    }.width('100%').padding({ top: 10, bottom: 10 })
                    if (i !== undefined && i < 20) {
                      Divider().strokeWidth(1).color(ElysiaTheme.hairline())
                    }
                  },
                  (kv: [string, string]) => kv[0]
                )
              }
              .width('100%').padding({ left: 14, right: 14, top: 4, bottom: 4 })
              .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
              .margin({ top: 14 })
              SafeBottom()
            }
            .padding({ left: 16, right: 16 })
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }
    .width('100%').height('100%')
  }
}
