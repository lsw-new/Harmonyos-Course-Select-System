// 学生端 / 管理端 底部 TabBar

import { ElysiaTheme } from '../Theme';
import { AppFontFamily, AppFontSize } from '../constants/TextStyles';
import { AppIcon } from './AppIcon';

export interface TabItem {
  id: string;
  label: string;
  icon: string;
  route: string;
}

export const STUDENT_TABS: TabItem[] = [
  { id: 'home', label: '首页', icon: 'home', route: 'pages/HomePage' },
  { id: 'schedule', label: '课表', icon: 'schedule', route: 'pages/SchedulePage' },
  { id: 'prac', label: '实践', icon: 'practice', route: 'pages/PracticePage' },
  { id: 'grades', label: '成绩', icon: 'grades', route: 'pages/GradesPage' },
  { id: 'mine', label: '我的', icon: 'mine', route: 'pages/MinePage' }
];

export const ADMIN_TABS: TabItem[] = [
  { id: 'dashboard', label: '仪表盘', icon: 'dashboard', route: 'pages/AdminDashboardPage' },
  { id: 'students', label: '学生', icon: 'students', route: 'pages/AdminStudentsPage' },
  { id: 'courses', label: '课程', icon: 'course', route: 'pages/AdminCoursesPage' },
  { id: 'approvals', label: '审批', icon: 'approve', route: 'pages/AdminApprovalsPage' },
  { id: 'mine', label: '我的', icon: 'madame', route: 'pages/AdminProfilePage' }
];

@Component
export struct StudentTabBar {
  @Prop active: string = 'home';
  // 底部手势指示条避让高度（vp），由 EntryAbility 测量写入；随设备自适应。
  @StorageProp('safeBottom') safeBottom: number = 0;
  onTap?: (id: string, route: string) => void;

  build() {
    Row() {
      ForEach(STUDENT_TABS, (tab: TabItem) => {
        Column() {
          AppIcon({ name: tab.icon, iconSize: 24, dim: tab.id !== this.active })
          Text(tab.label)
            .fontSize(AppFontSize.small)
            .fontStyle(FontStyle.Italic)
            .fontColor(tab.id === this.active ? ElysiaTheme.ROSE_600 : ElysiaTheme.INK_MUTE)
            .margin({ top: 2 })
            .fontFamily(AppFontFamily.display)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          if (this.onTap) this.onTap(tab.id, tab.route);
        })
      })
    }
    .width('100%')
    .padding({ top: 8, bottom: 14 + this.safeBottom, left: 14, right: 14 })
    .backgroundColor(ElysiaTheme.barBg())
    .border({ width: { top: 1 }, color: ElysiaTheme.hairlineSoft() })
  }
}

@Component
export struct AdminTabBar {
  @Prop active: string = 'dashboard';
  // 底部手势指示条避让高度（vp），由 EntryAbility 测量写入；随设备自适应。
  @StorageProp('safeBottom') safeBottom: number = 0;
  onTap?: (id: string, route: string) => void;

  build() {
    Row() {
      ForEach(ADMIN_TABS, (tab: TabItem) => {
        Column() {
          AppIcon({ name: tab.icon, iconSize: 24, dim: tab.id !== this.active })
          Text(tab.label)
            .fontSize(AppFontSize.small)
            .fontStyle(FontStyle.Italic)
            .fontColor(tab.id === this.active ? ElysiaTheme.ROSE_600 : ElysiaTheme.INK_MUTE)
            .margin({ top: 2 })
            .fontFamily(AppFontFamily.display)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          if (this.onTap) this.onTap(tab.id, tab.route);
        })
      })
    }
    .width('100%')
    .padding({ top: 8, bottom: 14 + this.safeBottom, left: 14, right: 14 })
    .backgroundColor(ElysiaTheme.barBg())
    .border({ width: { top: 1 }, color: ElysiaTheme.hairlineSoft() })
  }
}
