// 实践报名确认 · Practice Signup
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { PracticeRepository } from '../repositories/PracticeRepository';
import { PracticeProjectDetail, PracticeCategory } from '../models/PracticeModels';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { HttpError } from '../common/http/HttpError';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { Toast } from '../common/widgets/Feedback';

function categoryLabel(c: PracticeCategory): string {
  if (c === 'internship') {
    return '企业实习';
  }
  if (c === 'research') {
    return '科研训练';
  }
  if (c === 'social') {
    return '社会实践';
  }
  return '志愿服务';
}

@Component
struct PracticeSignupPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State detail: PracticeProjectDetail | null = null;
  @State submitting: boolean = false;
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.PracticeSignup)) {
      return;
    }
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少项目 ID';
      this.loading = false;
      return;
    }
    PracticeRepository.get().getDetail(id).then((d: PracticeProjectDetail) => {
      this.detail = d;
      this.loading = false;
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private doSignUp(): void {
    if (this.submitting || this.detail === null) {
      return;
    }
    this.submitting = true;
    PracticeRepository.get().signUp(this.detail!.id).then(() => {
      this.submitting = false;
      Toast.show(this.getUIContext(), '报名成功');
      AppRoute.back();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : (e instanceof Error ? e.message : '报名失败');
      Toast.show(this.getUIContext(), msg);
    });
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.practicesignup_title'), subtitle: $r('app.string.practicesignup_subtitle'), onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.detail !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // Hero：项目标题卡
              Column({ space: 10 }) {
                Row({ space: 6 }) {
                  Pill({ text: categoryLabel(this.detail!.category), bg: '#EFE4FF', color: ElysiaTheme.LAV_500 })
                  Pill({ text: `${this.detail!.credits} 学分`, bg: '#FBE6C2', color: ElysiaTheme.GOLD_700 })
                }
                Text(`${this.detail!.org} · ${this.detail!.title}`)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).lineHeight(26)
                Text(this.detail!.period)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              }
              .width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 指标卡：学分 / 名额 / 周期
              Row({ space: 10 }) {
                this.MetricCard(`${this.detail!.credits}`, '学分', ElysiaTheme.ROSE_500)
                this.MetricCard(`${this.detail!.slotsTaken}/${this.detail!.slotsTotal}`, '名额', ElysiaTheme.LAV_500)
                this.MetricCard(this.detail!.period, '周期', ElysiaTheme.GOLD_700)
              }.width('100%')

              // 报名信息卡
              Column({ space: 12 }) {
                Text($r('app.string.practicesignup_info')).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')
                this.InfoRow('course', '主办单位', this.detail!.org)
                this.InfoRow('teacher', '指导老师', this.detail!.mentor)
                this.InfoRow('location', '实践地点', this.detail!.location)
                this.InfoRow('time', '实践周期', this.detail!.period)
                this.InfoRow('file', '名额情况', `已报名 ${this.detail!.slotsTaken}/${this.detail!.slotsTotal}`)
              }
              .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 项目简介
              Column({ space: 8 }) {
                Text($r('app.string.practicesignup_desc')).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')
                Text(this.detail!.description)
                  .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(20).width('100%')
              }
              .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 报名要求
              if (this.detail!.requirements.length > 0) {
                Column({ space: 8 }) {
                  Text($r('app.string.practicesignup_req')).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).width('100%')
                  ForEach(this.detail!.requirements, (req: string, idx: number) => {
                    Row() {
                      AppIcon({ name: 'approve', iconSize: 14, mRight: 8, mTop: 2 })
                      Text(req).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(20).layoutWeight(1)
                    }.width('100%').alignItems(VerticalAlign.Top)
                  }, (req: string, idx: number) => `req-${idx}`)
                }
                .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              // 操作按钮
              Row({ space: 12 }) {
                GhostButton({ text: $r('app.string.practicesignup_btn_back'), onTap: () => AppRoute.back() })
                PrimaryButton({
                  text: this.submitting ? $r('app.string.common_submitting_zh') : $r('app.string.practicesignup_btn_confirm'),
                  onTap: () => this.doSignUp()
                })
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

  @Builder MetricCard(value: string, label: string, color: string) {
    Column() {
      Text(value)
        .fontSize(18).fontStyle(FontStyle.Italic).fontWeight(FontWeight.Bold)
        .fontColor(color).fontFamily(ElysiaTheme.FONT_DISPLAY)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
    }
    .layoutWeight(1).height(70)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(ElysiaTheme.glass())
    .border({ width: 1, color: ElysiaTheme.hairline() })
    .borderRadius(18)
  }

  @Builder InfoRow(icon: string, label: string, value: string) {
    Row() {
      AppIcon({ name: icon, iconSize: 16, mRight: 8 })
      Text(label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
      Text(value || '—').fontSize(12).fontColor(ElysiaTheme.INK).layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Center)
    .padding({ top: 6, bottom: 6 })
    .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
  }
}

@Builder
export function PracticeSignupPageBuilder() {
  NavDestination() {
    PracticeSignupPage()
  }
  .hideTitleBar(true)
}
