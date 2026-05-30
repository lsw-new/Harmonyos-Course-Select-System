// 实践项目详情 · Practice Detail（push 子页）
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute } from '../app/AppRoute';
import { PracticeRepository } from '../repositories/PracticeRepository';
import { PracticeProjectDetail, PracticeCategory } from '../models/PracticeModels';
import { HttpError } from '../common/http/HttpError';
import promptAction from '@ohos.promptAction';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

function categoryLabel(c: PracticeCategory): string {
  if (c === 'internship') return '企业实习';
  if (c === 'research') return '科研训练';
  if (c === 'social') return '社会实践';
  return '志愿服务';
}

// 单条信息行的数据模型（图标 + 标签 + 值）。
class InfoRow {
  icon: string = '';
  label: string = '';
  value: string = '';
  constructor(icon: string, label: string, value: string) {
    this.icon = icon;
    this.label = label;
    this.value = value;
  }
}

@Entry
@Component
struct PracticeDetailPage {
  @State detail: PracticeProjectDetail | undefined = undefined;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State submitting: boolean = false;
  @State confirmingCancel: boolean = false;
  private projectId: string = '';

  aboutToAppear(): void {
    this.projectId = AppRoute.getParam<string>('id', '');
    this.loadData();
  }

  private loadData(): void {
    if (this.projectId.length === 0) {
      this.loading = false;
      this.errorMsg = '缺少项目编号';
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    PracticeRepository.get().getDetail(this.projectId).then((d: PracticeProjectDetail) => {
      this.detail = d;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private buildInfoRows(d: PracticeProjectDetail): InfoRow[] {
    return [
      new InfoRow('course', '主办单位', d.org),
      new InfoRow('star', '学分', `${d.credits} 学分`),
      new InfoRow('time', '周期', d.period),
      new InfoRow('location', '地点', d.location),
      new InfoRow('teacher', '指导老师', d.mentor),
      new InfoRow('file', '名额', `已报名 ${d.slotsTaken}/${d.slotsTotal}`)
    ];
  }

  private doSignUp(): void {
    if (this.submitting) {
      return;
    }
    const current = this.detail;
    if (current === undefined) {
      return;
    }
    if (current.slotsTaken >= current.slotsTotal) {
      promptAction.showToast({ message: '该项目名额已满' });
      return;
    }
    this.submitting = true;
    PracticeRepository.get().signUp(current.id).then(() => {
      this.submitting = false;
      promptAction.showToast({ message: '报名成功' });
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '报名失败';
      promptAction.showToast({ message: msg });
    });
  }

  private doCancel(): void {
    if (this.submitting) {
      return;
    }
    const current = this.detail;
    if (current === undefined) {
      return;
    }
    this.submitting = true;
    this.confirmingCancel = false;
    PracticeRepository.get().cancelSignUp(current.id).then(() => {
      this.submitting = false;
      promptAction.showToast({ message: '已取消报名' });
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '取消失败';
      promptAction.showToast({ message: msg });
    });
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: '实践', subtitle: '实 践 详 情', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({ tip: '正在加载项目详情...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.detail === undefined) {
          EmptyState({ icon: 'practice', title: '项目不存在' })
        } else {
          this.DetailBody(this.detail!)
        }
      }

      // 取消报名确认浮层
      if (this.confirmingCancel) {
        this.CancelOverlay()
      }
    }
    .width('100%').height('100%')
  }

  @Builder DetailBody(d: PracticeProjectDetail) {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          // 标题卡
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Pill({ text: categoryLabel(d.category), bg: '#EFE4FF', color: ElysiaTheme.LAV_500 })
              if (d.signedUp) {
                Pill({ text: '已报名', bg: '#E6F5EC', color: '#3E8E5E' })
              } else if (d.slotsTaken >= d.slotsTotal) {
                Pill({ text: '已满', bg: '#F0F0F0', color: ElysiaTheme.INK_MUTE })
              } else {
                Pill({ text: '可报名' })
              }
            }.width('100%')
            Text(d.title).fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
              .width('100%')
            Text(d.org).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).width('100%')
          }
          .width('100%').padding(16).borderRadius(22)
          .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })

          // 基本信息
          Column({ space: 10 }) {
            Text('项目信息').fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              .width('100%')
            ForEach(this.buildInfoRows(d), (row: InfoRow) => {
              Row() {
                AppIcon({ name: row.icon, iconSize: 16, mRight: 8 })
                Text(row.label).fontSize(12).fontColor(ElysiaTheme.INK_MUTE).width(72)
                Text(row.value).fontSize(12).fontColor(ElysiaTheme.INK).layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Center)
            }, (row: InfoRow) => row.label)
          }
          .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
          .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

          // 项目简介
          Column({ space: 8 }) {
            Text('项目简介').fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              .width('100%')
            Text(d.description).fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
              .lineHeight(20).width('100%')
          }
          .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
          .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

          // 报名要求
          if (d.requirements.length > 0) {
            Column({ space: 8 }) {
              Text('报名要求').fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                .width('100%')
              ForEach(d.requirements, (req: string, idx: number) => {
                Row() {
                  AppIcon({ name: 'approve', iconSize: 14, mRight: 8, mTop: 2 })
                  Text(req).fontSize(12).fontColor(ElysiaTheme.INK_SOFT).lineHeight(20).layoutWeight(1)
                }.width('100%').alignItems(VerticalAlign.Top)
              }, (req: string, idx: number) => `req-${idx}`)
            }
            .width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
          }

          SafeBottom()
        }
        .padding({ left: 16, right: 16, top: 4 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      // 底部操作区
      Column() {
        this.PrimaryAction(d)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 18 })
      .backgroundColor(ElysiaTheme.barBg())
      .border({ width: { top: 1 }, color: ElysiaTheme.hairlineSoft() })
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder PrimaryAction(d: PracticeProjectDetail) {
    if (d.signedUp) {
      GhostButton({
        text: this.submitting ? '处理中...' : '取消报名',
        onTap: () => {
          if (!this.submitting) {
            this.confirmingCancel = true;
          }
        }
      })
    } else if (d.slotsTaken >= d.slotsTotal) {
      Button('名额已满')
        .height(46).width('100%').fontSize(14).fontWeight(FontWeight.Bold)
        .fontColor(ElysiaTheme.INK_MUTE)
        .backgroundColor('#F0F0F0')
        .borderRadius(999)
        .enabled(false)
    } else {
      PrimaryButton({
        text: this.submitting ? '提交中...' : '报 名',
        onTap: () => this.doSignUp()
      })
    }
  }

  @Builder CancelOverlay() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor(ElysiaTheme.scrim())
        .onClick(() => { this.confirmingCancel = false; })

      Column({ space: 14 }) {
        AppIcon({ name: 'info', iconSize: 36 })
        Text('确认取消报名？').fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
        Text('取消后名额将释放，如需再次参与请重新报名。')
          .fontSize(12).fontColor(ElysiaTheme.INK_SOFT).textAlign(TextAlign.Center)
        Row({ space: 10 }) {
          GhostButton({ text: '再想想', onTap: () => { this.confirmingCancel = false; } }).layoutWeight(1)
          PrimaryButton({ text: '确认取消', onTap: () => this.doCancel() }).layoutWeight(1)
        }.width('100%')
      }
      .width('80%').padding(22).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
      .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%').height('100%')
  }
}
