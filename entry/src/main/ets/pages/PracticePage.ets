// 实践与公服 · Practice
import { ElysiaTheme } from '../common/Theme';
import { TopBar, RoseDivider, Pill } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { PracticeEntry } from '../models/Misc';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute } from '../app/AppRoute';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct PracticePage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State entries: PracticeEntry[] = [];

  aboutToAppear(): void {
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    ProfileRepository.get().getPracticeEntries().then((list: PracticeEntry[]) => {
      this.entries = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Practice', subtitle: '实 践 与 公 服', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({ tip: '正在加载...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.entries.length === 0) {
          EmptyState({ title: '暂无实践项目' })
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
        AppIcon({ name: 'forward', iconSize: 16 })
      }
    }
    .width('100%').padding(14)
    .backgroundColor(item.available ? ElysiaTheme.SURFACE : '#F8F8F8')
    .borderRadius(14).border({ width: 1, color: '#66FFB3CE' })
    .opacity(item.available ? 1.0 : 0.6)
    .margin({ bottom: 8 })
    .onClick(() => {
      if (item.available) {
        if (item.url !== undefined && item.url.length > 0) {
          AppRoute.go(item.url);
        } else {
          promptAction.showToast({ message: '该功能正在建设中' });
        }
      } else {
        promptAction.showToast({ message: '该功能正在建设中' });
      }
    })
  }
}
