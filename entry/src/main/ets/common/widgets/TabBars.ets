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
  { id: 'home', label: 'Home', icon: 'home', route: 'pages/HomePage' },
  { id: 'mine', label: 'Mine', icon: 'mine', route: 'pages/MinePage' },
  { id: 'eval', label: 'Eval', icon: 'evaluation', route: 'pages/EvalPage' },
  { id: 'prac', label: 'Prac', icon: 'practice', route: 'pages/PracticePage' },
  { id: 'pub', label: 'Pub', icon: 'public', route: 'pages/NoticesPage' }
];

export const ADMIN_TABS: TabItem[] = [
  { id: 'dashboard', label: 'Tableau', icon: 'dashboard', route: 'pages/AdminDashboardPage' },
  { id: 'students', label: 'Students', icon: 'students', route: 'pages/AdminStudentsPage' },
  { id: 'courses', label: 'Cours', icon: 'course', route: 'pages/AdminCoursesPage' },
  { id: 'approvals', label: 'Approve', icon: 'approve', route: 'pages/AdminApprovalsPage' },
  { id: 'mine', label: 'Madame', icon: 'madame', route: 'pages/AdminProfilePage' }
];

@Component
export struct StudentTabBar {
  @Prop active: string = 'home';
  @StorageProp('darkMode') darkMode: boolean = false;
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
    .backgroundColor(ElysiaTheme.barBg(this.darkMode))
    .border({ width: { top: 1 }, color: ElysiaTheme.hairlineSoft(this.darkMode) })
  }
}

@Component
export struct AdminTabBar {
  @Prop active: string = 'dashboard';
  @StorageProp('darkMode') darkMode: boolean = false;
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
    .backgroundColor(ElysiaTheme.barBg(this.darkMode))
    .border({ width: { top: 1 }, color: ElysiaTheme.hairlineSoft(this.darkMode) })
  }
}
