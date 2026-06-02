// 我的账户 · Account
import promptAction from '@ohos.promptAction';
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, Monogram } from '../common/Components';
import { AppIcon } from '../common/widgets/AppIcon';
import { LoadingState, ErrorState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { SessionStorage } from '../common/storage/SessionStorage';
import { AuthRepository } from '../repositories/AuthRepository';
import { AccountInfo, LoginHistoryItem } from '../models/User';
import { SafeTop } from '../common/widgets/SafeArea';

@Entry
@Component
struct AccountPage {
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State account: AccountInfo | null = null;
  @State history: LoginHistoryItem[] = [];
  @State showLogoutConfirm: boolean = false;

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Account)) {
      return;
    }
    this.loadData();
  }

  loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    const repo = AuthRepository.get();
    Promise.all([repo.getAccount(), repo.getLoginHistory()])
      .then((res: [AccountInfo, LoginHistoryItem[]]) => {
        this.account = res[0];
        this.history = res[1];
        this.loading = false;
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  private statusLabel(s: string): string {
    if (s === 'active') return '激活';
    if (s === 'locked') return '已锁定';
    return '待激活';
  }

  private statusColor(s: string): string {
    if (s === 'active') return '#3F7A4A';
    if (s === 'locked') return '#D8546B';
    return ElysiaTheme.INK_MUTE;
  }

  private statusBg(s: string): string {
    if (s === 'active') return '#D8F0D8';
    if (s === 'locked') return '#FFE4E8';
    return '#F0F0F0';
  }

  private logout(): void {
    SessionStorage.get().clear().then(() => {
      AppRoute.clearTo(Routes.Login);
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
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: '账户', subtitle: '我 的 账 户', onBack: () => AppRoute.back() })

        if (this.loading) {
          LoadingState({ tip: '正在加载账户信息...' })
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else {
          Scroll() {
            Column() {
              // Account hero card
              Column() {
                Row() {
                  Monogram({ iconSize: 56 })
                  Blank().layoutWeight(1)
                  Pill({
                    text: this.statusLabel(this.account?.status ?? 'pending'),
                    bg: this.statusBg(this.account?.status ?? 'pending'),
                    color: this.statusColor(this.account?.status ?? 'pending')
                  })
                }
                Text(this.account?.name ?? '—')
                  .fontSize(24).fontStyle(FontStyle.Italic)
                  .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
                  .margin({ top: 14 })
                Text(`${this.account?.studentId ?? '—'} · ${this.account?.email ?? '—'}`)
                  .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
              }
              .width('100%').alignItems(HorizontalAlign.Start).padding(20).borderRadius(24)
              .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.LAV_200, 0.7], ['#FFF1D6', 1]] })

              // Action tiles
              Row({ space: 10 }) {
                Column() {
                  AppIcon({ name: 'lock', iconSize: 24 })
                  Text('修改密码').fontSize(11).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).margin({ top: 6 })
                }.layoutWeight(1).padding({ top: 14, bottom: 14 })
                .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                .onClick(() => { AppRoute.go(Routes.Password); })

                Column() {
                  AppIcon({ name: 'camera', iconSize: 24 })
                  Text('更换头像').fontSize(11).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).margin({ top: 6 })
                }.layoutWeight(1).padding({ top: 14, bottom: 14 })
                .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                .onClick(() => { AppRoute.go(Routes.EditInfo); })

                Column() {
                  AppIcon({ name: 'close', iconSize: 24 })
                  Text('退出登录').fontSize(11).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK).margin({ top: 6 })
                }.layoutWeight(1).padding({ top: 14, bottom: 14 })
                .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({ width: 1, color: ElysiaTheme.hairlineSoft() })
                .onClick(() => { this.showLogoutConfirm = true; })
              }.width('100%').margin({ top: 18 })

              // Login history
              Column() {
                ForEach(this.history, (item: LoginHistoryItem, idx?: number) => {
                  this.HistoryRow(item, idx !== undefined && idx >= this.history.length - 1)
                }, (item: LoginHistoryItem) => item.id)
              }
              .width('100%').padding({ left: 14, right: 14 }).margin({ top: 18, bottom: 30 })
              .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22).border({ width: 1, color: ElysiaTheme.hairlineSoft() })
            }
            .padding({ left: 16, right: 16 })
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }

      // Logout confirm dialog
      if (this.showLogoutConfirm) {
        Column() {
          Column({ space: 14 }) {
            Text('确认退出登录？').fontSize(16).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            Text('退出后需重新登录').fontSize(12).fontColor(ElysiaTheme.INK_SOFT)
            Row({ space: 12 }) {
              Text('取消').fontSize(14).fontColor(ElysiaTheme.INK_SOFT)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor('#E0FFFFFF').borderRadius(999)
                .onClick(() => { this.showLogoutConfirm = false; })
              Text('退出').fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
                .onClick(() => { this.logout(); })
            }.margin({ top: 8 })
          }.padding(24).backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
          .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor(ElysiaTheme.scrim())
        .onClick(() => { this.showLogoutConfirm = false; })
      }
    }
    .width('100%').height('100%')
  }

  @Builder HistoryRow(item: LoginHistoryItem, isLast: boolean) {
    Row() {
      Stack().width(8).height(8).borderRadius(4).backgroundColor(ElysiaTheme.ROSE_500)
      Column() {
        Text(item.loginTime)
          .fontSize(12).fontStyle(FontStyle.Italic).fontColor(ElysiaTheme.INK)
          .fontFamily(ElysiaTheme.FONT_DISPLAY).fontWeight(FontWeight.Medium)
        Text(`${item.location} · ${item.ipAddress}`)
          .fontSize(10).fontColor(ElysiaTheme.INK_SOFT).margin({ top: 2 })
      }.alignItems(HorizontalAlign.Start).margin({ left: 10 }).layoutWeight(1)
      Text(`在线 ${item.durationMinutes} 分钟`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
    }.width('100%').padding({ top: 10, bottom: 10 })
    if (!isLast) { Divider().strokeWidth(1).color(ElysiaTheme.hairline()) }
  }
}
