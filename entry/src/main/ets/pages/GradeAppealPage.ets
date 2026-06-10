// 成绩申诉 · Grade Appeal
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AcademicRepository } from '../repositories/AcademicRepository';
import { GradeRecord } from '../models/Academic';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

@Component
struct GradeAppealPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State grade: GradeRecord | null = null;
  @State reason: string = '';
  @State formError: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.GradeAppeal)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少成绩 ID';
      this.loading = false;
      return;
    }
    AcademicRepository.get().getGrades().then((records: GradeRecord[]) => {
      const found: GradeRecord | undefined = records.find((r: GradeRecord) => r.id === id);
      if (found === undefined) {
        this.errorMsg = '成绩不存在';
      } else {
        this.grade = found;
      }
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private submitAppeal(): void {
    if (this.reason.trim().length === 0) {
      this.formError = '请填写复核理由';
      Toast.show(this.getUIContext(), '请填写复核理由');
      return;
    }
    this.formError = '';
    Toast.show(this.getUIContext(), '申诉已提交，请等待复核');
    AppRoute.back();
  }

  private saveDraft(): void {
    Toast.show(this.getUIContext(), '已保存草稿');
  }

  @Builder InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(84)
      Text(value || '—').fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.gradeappeal_title'), subtitle: $r('app.string.gradeappeal_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.grade !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero 上下文卡：展示申诉的课程与当前分数
              Column({ space: 8 }) {
                Pill({ text: `${this.grade!.courseCategory} · ${this.grade!.credit} 学分` })
                Text(this.grade!.courseName)
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ElysiaTheme.INK)
                  .lineHeight(26)
                Text(`当前成绩：${this.grade!.finalScore ?? this.grade!.totalScore ?? '—'}`)
                  .fontSize(12)
                  .fontColor(ElysiaTheme.INK_SOFT)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(18)
              .borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 成绩信息摘要
              Column() {
                Text($r('app.string.gradeappeal_section_info'))
                  .fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                this.InfoRow('课程代码', this.grade!.courseCode)
                this.InfoRow('教学班', this.grade!.teachingClassNo)
                this.InfoRow('学期', this.grade!.term)
                this.InfoRow('当前成绩', `${this.grade!.finalScore ?? this.grade!.totalScore ?? '—'}`)
                this.InfoRow('绩点', `${this.grade!.gradePoint ?? '—'}`)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 申诉理由表单
              Column({ space: 8 }) {
                Row({ space: 6 }) {
                  Text($r('app.string.gradeappeal_label_reason'))
                    .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                  Pill({ text: $r('app.string.gradeappeal_pill_required') })
                }
                TextArea({ text: this.reason, placeholder: $r('app.string.gradeappeal_placeholder_reason') })
                  .height(140)
                  .fontSize(13)
                  .fontColor(ElysiaTheme.INK)
                  .placeholderColor(ElysiaTheme.INK_MUTE)
                  .backgroundColor(ElysiaTheme.glass())
                  .borderRadius(14)
                  .border({ width: 1, color: this.formError.length > 0 ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
                  .padding(12)
                  .onChange((val: string) => {
                    this.reason = val;
                    if (val.trim().length > 0) {
                      this.formError = '';
                    }
                  })
                if (this.formError.length > 0) {
                  Text(this.formError)
                    .fontSize(12)
                    .fontColor(ElysiaTheme.ROSE_700)
                    .width('100%')
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(ElysiaTheme.SURFACE)
              .borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({ text: $r('app.string.gradeappeal_btn_save_draft'), onTap: () => this.saveDraft() })
                PrimaryButton({ text: $r('app.string.gradeappeal_btn_submit'), onTap: () => this.submitAppeal() })
              }.width('100%')

              SafeBottom()
            }.padding({ left: 16, right: 16, bottom: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function GradeAppealPageBuilder() {
  NavDestination() {
    GradeAppealPage()
  }
  .hideTitleBar(true)
}
