// 通知详情 · Notice Detail
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseDivider } from '../common/Components';
import { CourseRepository } from '../repositories/CourseRepository';
import { Notice, NoticeAttachment } from '../models/Notice';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppIcon } from '../common/widgets/AppIcon';
import { HttpError } from '../common/http/HttpError';
import promptAction from '@ohos.promptAction';
import { FileService } from '../common/services/FileService';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

@Entry
@Component
struct NoticeDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State notice: Notice | null = null;

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.NoticeDetail)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    const id: string = AppRoute.getParam<string>('id', '');
    if (id.length === 0) {
      this.errorMsg = '缺少通知 ID';
      this.loading = false;
      return;
    }
    CourseRepository.get().getNoticeDetail(id).then((n: Notice) => {
      this.notice = n;
      this.loading = false;
      CourseRepository.get().markNoticeRead(id);
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  private downloadAttachment(att: NoticeAttachment): void {
    FileService.downloadFile(att.fileUrl, att.fileName).then((path: string) => {
      promptAction.showToast({ message: `已下载：${path}` });
    }).catch((e: object) => {
      const message = e instanceof Error ? e.message : '下载失败';
      promptAction.showToast({ message });
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
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: '通知详情', subtitle: '通 知 详 情', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({ tip: '正在加载通知...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.notice !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // 标题区
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Pill({ text: this.notice!.category })
                  if (this.notice!.isRead) {
                    Pill({ text: '已读', color: '#7BB07B', bg: '#E8F8E8' })
                  }
                }
                Text(this.notice!.title)
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
                  .margin({ top: 6 })
                Text(`${this.notice!.publisher} · ${this.notice!.publishedAt}`)
                  .fontSize(11).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 4 })
              }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(22)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.LAV_200, 1]] })

              RoseDivider({ label: '正文' })

              // 正文
              Column() {
                Text(this.notice!.content)
                  .fontSize(14).fontColor(ElysiaTheme.INK).lineHeight(22)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: ElysiaTheme.hairlineSoft() })

              // 附件
              if (this.notice!.attachments.length > 0) {
                Column({ space: 8 }) {
                  Text('附件').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                  ForEach(this.notice!.attachments, (att: NoticeAttachment) => {
                    Row() {
                      AppIcon({ name: 'file', iconSize: 16, mRight: 8 })
                      Column() {
                        Text(att.fileName).fontSize(13).fontColor(ElysiaTheme.INK)
                        if (att.fileSize) {
                          Text(`${(att.fileSize! / 1024).toFixed(0)} KB`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                        }
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                      Text('下载').fontSize(11).fontColor(ElysiaTheme.ROSE_500)
                        .onClick(() => this.downloadAttachment(att))
                    }.width('100%').padding(12).backgroundColor(ElysiaTheme.SURFACE_GLOW).borderRadius(12)
                    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                  }, (att: NoticeAttachment) => att.id)
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }

              SafeBottom()
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
    }.width('100%').height('100%')
  }
}
