// 选课管理 · Sélection
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseDivider } from '../common/Components';
import { AdminRepository } from '../repositories/AdminRepository';
import { SelectionRound } from '../models/Admin';
import { LoadingState } from '../common/widgets/StateViews';

@Entry
@Component
struct AdminSelectionPage {
  @State loading: boolean = true;
  @State rounds: SelectionRound[] = [];

  aboutToAppear(): void {
    AdminRepository.get().getSelectionRounds().then((list: SelectionRound[]) => {
      this.rounds = list;
      this.loading = false;
    }).catch(() => { this.loading = false; });
  }

  private statusLabel(s: string): string {
    if (s === 'running') return '进行中';
    if (s === 'ended') return '已结束';
    return '未开始';
  }

  private statusColor(s: string): string {
    if (s === 'running') return '#7BB07B';
    if (s === 'ended') return ElysiaTheme.INK_MUTE;
    return '#D9B675';
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Sélection', subtitle: '选 课 管 理', onBack: () => router.back() })

        if (this.loading) {
          LoadingState({})
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // 当前轮次（running）
              ForEach(this.rounds.filter((r: SelectionRound) => r.status === 'running'), (r: SelectionRound) => {
                Column({ space: 8 }) {
                  Row() {
                    Text(r.name).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
                    Pill({ text: '进行中', color: '#7BB07B', bg: '#E8F8E8' })
                  }.width('100%')
                  Text(`${r.startTime} ~ ${r.endTime}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)

                  // 进度条
                  Row() {
                    Column().height(8).width(`${r.progressPercent}%`).backgroundColor(ElysiaTheme.ROSE_500).borderRadius(4)
                  }.width('100%').height(8).backgroundColor('#FFE9F1').borderRadius(4)
                  Text(`进度 ${r.progressPercent}%`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)

                  // 统计
                  Row({ space: 0 }) {
                    this.MiniStat('参与', String(r.participantCount))
                    this.MiniStat('选课', String(r.selectionCount))
                    this.MiniStat('学分', r.averageCredit.toFixed(1))
                    this.MiniStat('冲突', String(r.conflictCount))
                  }.width('100%')
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: '#66FFB3CE' })
              }, (r: SelectionRound) => r.id + '_running')

              RoseDivider({ label: 'all rounds' })

              // 所有轮次
              ForEach(this.rounds, (r: SelectionRound) => {
                Row() {
                  Column() {
                    Text(r.name).fontSize(14).fontColor(ElysiaTheme.INK)
                    Text(`${r.startTime} ~ ${r.endTime}`).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Pill({ text: this.statusLabel(r.status), color: this.statusColor(r.status), bg: '#FFF6FA' })
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: '#66FFB3CE' }).margin({ bottom: 8 })
              }, (r: SelectionRound) => r.id)

              Blank().height(40)
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
    }.width('100%').height('100%')
  }

  @Builder MiniStat(label: string, value: string) {
    Column() {
      Text(value).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_500)
      Text(label).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}
