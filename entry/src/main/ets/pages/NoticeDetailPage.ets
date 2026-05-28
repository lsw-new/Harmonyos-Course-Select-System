// 通知详情 · Notice Detail
import router from '@ohos.router';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, RoseDivider, GhostButton } from '../common/Components';
import { CourseRepository } from '../repositories/CourseRepository';
import { Notice, NoticeAttachment } from '../models/Notice';
import { AppRoute } from '../app/AppRoute';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';

@Entry
@Component
struct NoticeDetailPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State notice: Notice | null = null;

  aboutToAppear(): void {
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

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [[ElysiaTheme.ROSE_50, 0], [ElysiaTheme.CREAM_50, 0.55], ['#FFF0F5', 1]] })

      Column() {
        Blank().height(40)
        TopBar({ title: 'Notice', subtitle: '通 知 详 情', onBack: () => router.back() })

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg })
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

              RoseDivider({ label: 'content' })

              // 正文
              Column() {
                Text(this.notice!.content)
                  .fontSize(14).fontColor(ElysiaTheme.INK).lineHeight(22)
              }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
              .border({ width: 1, color: '#66FFB3CE' })

              // 附件
              if (this.notice!.attachments.length > 0) {
                Column({ space: 8 }) {
                  Text('附件').fontSize(12).fontColor(ElysiaTheme.INK_MUTE).margin({ bottom: 4 })
                  ForEach(this.notice!.attachments, (att: NoticeAttachment) => {
                    Row() {
                      Text('📎').fontSize(14).margin({ right: 8 })
                      Column() {
                        Text(att.fileName).fontSize(13).fontColor(ElysiaTheme.INK)
                        if (att.fileSize) {
                          Text(`${(att.fileSize! / 1024).toFixed(0)} KB`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 })
                        }
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                      Text('下载').fontSize(11).fontColor(ElysiaTheme.ROSE_500)
                    }.width('100%').padding(12).backgroundColor('#FFF6FA').borderRadius(12)
                    .border({ width: 1, color: '#66FFB3CE' })
                  }, (att: NoticeAttachment) => att.id)
                }.width('100%').padding(16).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
                .border({ width: 1, color: '#66FFB3CE' })
              }

              Blank().height(40)
            }.padding({ left: 16, right: 16 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
    }.width('100%').height('100%')
  }
}
