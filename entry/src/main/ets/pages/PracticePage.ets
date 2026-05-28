// 实践与公服 · Practice
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, Pill } from '../common/Components';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { PracticeEntry } from '../models/Misc';
import { LoadingState } from '../common/widgets/StateViews';

@Entry
@Component
struct PracticePage {
  @State loading: boolean = true;
  @State entries: PracticeEntry[] = [];

  aboutToAppear(): void {
    ProfileRepository.get().getPracticeEntries().then((list: PracticeEntry[]) => {
      this.entries = list;
      this.loading = false;
    }).catch(() => { this.loading = false; });
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Practice', subtitle: '实 践 与 公 服', onBack: () => router.back() })

        if (this.loading) {
          LoadingState({})
        } else {
          Scroll() {
            Column({ space: 14 }) {
              // 实践模块
              Column() {
                Text('实践模块').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 8 })
                ForEach(this.entries.filter((e: PracticeEntry) =>
                  e.key === 'intern' || e.key === 'central' || e.key === 'social' || e.key === 'volunteer'
                ), (item: PracticeEntry) => {
                  this.EntryCard(item)
                }, (item: PracticeEntry) => item.key)
              }.width('100%')

              RoseDivider({ label: 'public service' })

              // 公共服务
              Column() {
                Text('公共服务').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 8 })
                ForEach(this.entries.filter((e: PracticeEntry) =>
                  e.key !== 'intern' && e.key !== 'central' && e.key !== 'social' && e.key !== 'volunteer'
                ), (item: PracticeEntry) => {
                  this.EntryCard(item)
                }, (item: PracticeEntry) => item.key)
              }.width('100%')

              Blank().height(40)
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
    }.width('100%').height('100%')
  }

  @Builder EntryCard(item: PracticeEntry) {
    Row() {
      Column() {
        Text(item.label).fontSize(14).fontColor(item.available ? ElysiaTheme.INK : ElysiaTheme.INK_MUTE)
        Text(item.description).fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (!item.available) {
        Pill({ text: '建设中', color: ElysiaTheme.INK_MUTE, bg: '#F0F0F0' })
      } else {
        Text('›').fontSize(16).fontColor(ElysiaTheme.ROSE_500)
      }
    }
    .width('100%').padding(14)
    .backgroundColor(item.available ? ElysiaTheme.SURFACE : '#F8F8F8')
    .borderRadius(14).border({ width: 1, color: '#66FFB3CE' })
    .opacity(item.available ? 1.0 : 0.6)
    .margin({ bottom: 8 })
  }
}
