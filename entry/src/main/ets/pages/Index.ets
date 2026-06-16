// 应用根容器 · 唯一 @Entry，托管全局 Navigation 返回栈。
// 初始路由按会话角色决定（会话已在 EntryAbility 的 AppStartup.init 后就绪）。
// 各业务页改造为系统路由表的 NavDestination，经 route_map.json 按名懒加载。
import { AppRoute, Routes } from '../app/AppRoute';
import { SessionStorage } from '../common/storage/SessionStorage';
import { NoticeAlertCenter } from '../common/services/NoticeAlertCenter';
import { NoticeAlertOverlay } from '../common/widgets/NoticeAlertOverlay';
import { CourseRepository } from '../repositories/CourseRepository';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    const session = SessionStorage.get();
    let start: string = Routes.Login;
    if (session.isAuthenticated()) {
      start = session.getRole() === 'admin' ? Routes.AdminDashboard : Routes.Home;
    }
    AppRoute.go(start);
    NoticeAlertCenter.start(() => CourseRepository.get().getNotices());
  }

  build() {
    Stack() {
      Navigation(AppRoute.stack) {
      }
      .hideNavBar(true)
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
      NoticeAlertOverlay()
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
