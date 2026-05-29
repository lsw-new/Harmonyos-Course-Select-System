// 评教管理 · Évaluation
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseDivider } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { EvaluationStats } from '../models/Admin';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute } from '../app/AppRoute';

class TemplateState {
  name: string;
  enabled: boolean;

  constructor(name: string, enabled: boolean) {
    this.name = name;
    this.enabled = enabled;
  }
}

@Entry
@Component
struct AdminEvalPage {
  @State loading: boolean = true;
  @State stats: EvaluationStats | null = null;
  @State errorMsg: string = '';
  @State templates: TemplateState[] = [];

  aboutToAppear(): void {
    this.templates = [
      new TemplateState('理工类课程通用评教问卷', true),
      new TemplateState('人文社科类课程评教问卷', true),
      new TemplateState('语言类课程评教问卷', true),
      new TemplateState('实践类课程评教问卷', false),
      new TemplateState('体育类课程评教问卷（草稿）', false),
    ];
    AdminRepository.get().getEvaluationStats().then((s: EvaluationStats) => {
      this.stats = s;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private statusLabel(s: string): string {
    if (s === 'open') return '开放中';
    if (s === 'closed') return '已关闭';
    return '草稿';
  }

  private statusColor(s: string): string {
    if (s === 'open') return '#7BB07B';
    if (s === 'closed') return ElysiaTheme.INK_MUTE;
    return '#D9B675';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Évaluation', subtitle: '评 教 管 理', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.aboutToAppear() })
        } else if (this.stats !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // 开放期卡片
              Column({ space: 8 }) {
                Row() {
                  Text('当前评教期').fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
                  Pill({ text: this.statusLabel(this.stats!.openStatus), color: this.statusColor(this.stats!.openStatus), bg: '#FFF6FA' })
                }.width('100%')
                Text(`${this.stats!.startTime} ~ ${this.stats!.endTime}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)

                // 统计指标
                Row({ space: 0 }) {
                  Column() {
                    Text(`${this.stats!.participationRate.toFixed(1)}%`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
                    Text('参与率').fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                  Column() {
                    Text(`${this.stats!.completionRate.toFixed(1)}%`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.LAV_500)
                    Text('完成率').fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                  Column() {
                    Text(this.stats!.averageScore.toFixed(2)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.GOLD_500)
                    Text('平均分').fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                  Column() {
                    Text(String(this.stats!.questionnaireCount)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                    Text('问卷数').fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                }.width('100%').margin({ top: 8 })
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#66FFB3CE' })

              RoseDivider({ label: 'distribution' })

              // 评分分布（模拟柱图）
              Column() {
                Text('评分分布').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 10 })
                Row({ space: 8 }) {
                  this.BarItem('5分', 42, ElysiaTheme.ROSE_500)
                  this.BarItem('4分', 35, ElysiaTheme.LAV_500)
                  this.BarItem('3分', 15, ElysiaTheme.GOLD_500)
                  this.BarItem('2分', 5, ElysiaTheme.INK_MUTE)
                  this.BarItem('1分', 3, ElysiaTheme.INK_MUTE)
                }.width('100%').height(100).alignItems(VerticalAlign.Bottom)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#66FFB3CE' })

              // 问卷模板
              Column() {
                Text('问卷模板').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 8 })
                ForEach(this.templates, (tmpl: TemplateState, idx: number) => {
                  Row() {
                    Text(tmpl.name).fontSize(13).fontColor(ElysiaTheme.INK).layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: tmpl.enabled })
                      .selectedColor(ElysiaTheme.ROSE_500)
                      .onChange((v: boolean) => {
                        this.templates[idx].enabled = v;
                        this.templates = this.templates.slice();
                      })
                  }.width('100%').padding({ top: 10, bottom: 10 })
                  .border({ width: { bottom: 1 }, color: '#15FFB3CE' })
                }, (tmpl: TemplateState, idx: number) => `tmpl-${idx}`)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#66FFB3CE' })

              Blank().height(40)
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
    }.width('100%').height('100%')
  }

  @Builder BarItem(label: string, percent: number, color: string) {
    Column() {
      Column().width(24).height(percent * 1.5).backgroundColor(color).borderRadius(4)
      Text(`${percent}%`).fontSize(9).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
      Text(label).fontSize(9).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
    }.alignItems(HorizontalAlign.Center).layoutWeight(1)
  }
}
