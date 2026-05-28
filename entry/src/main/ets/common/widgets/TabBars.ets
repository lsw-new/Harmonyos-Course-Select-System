// 学生端 / 管理端 底部 TabBar

import { ElysiaTheme } from '../Theme';
import { AppFontFamily, AppFontSize } from '../constants/TextStyles';

export interface TabItem {
  id: string;
  label: string;
  icon: string;
  route: string;
}

export const STUDENT_TABS: TabItem[] = [
  { id: 'home', label: 'Home', icon: '⌂', route: 'pages/HomePage' },
  { id: 'mine', label: 'Mine', icon: '○', route: 'pages/MinePage' },
  { id: 'eval', label: 'Eval', icon: '✦', route: 'pages/EvalPage' },
  { id: 'prac', label: 'Prac', icon: '❀', route: 'pages/PracticePage' },
  { id: 'pub', label: 'Pub', icon: '✧', route: 'pages/NoticesPage' }
];

export const ADMIN_TABS: TabItem[] = [
  { id: 'dashboard', label: 'Tableau', icon: '◐', route: 'pages/AdminDashboardPage' },
  { id: 'students', label: 'Students', icon: '◉', route: 'pages/AdminStudentsPage' },
  { id: 'courses', label: 'Cours', icon: '✿', route: 'pages/AdminCoursesPage' },
  { id: 'approvals', label: 'Approve', icon: '✎', route: 'pages/AdminApprovalsPage' },
  { id: 'mine', label: 'Madame', icon: '○', route: 'pages/AdminProfilePage' }
];

@Component
export struct StudentTabBar {
  @Prop active: string = 'home';
  onTap?: (id: string, route: string) => void;

  build() {
    Row() {
      ForEach(STUDENT_TABS, (tab: TabItem) => {
        Column() {
          Text(tab.icon)
            .fontSize(20)
            .fontColor(tab.id === this.active ? ElysiaTheme.ROSE_600 : ElysiaTheme.INK_MUTE)
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
    .height(64)
    .padding({ top: 8, bottom: 14, left: 14, right: 14 })
    .backgroundColor('#F2FFF6FA')
    .border({ width: { top: 1 }, color: '#33FFB3CE' })
  }
}

@Component
export struct AdminTabBar {
  @Prop active: string = 'dashboard';
  onTap?: (id: string, route: string) => void;

  build() {
    Row() {
      ForEach(ADMIN_TABS, (tab: TabItem) => {
        Column() {
          Text(tab.icon)
            .fontSize(20)
            .fontColor(tab.id === this.active ? ElysiaTheme.ROSE_600 : ElysiaTheme.INK_MUTE)
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
    .height(64)
    .padding({ top: 8, bottom: 14, left: 14, right: 14 })
    .backgroundColor('#F2FFF6FA')
    .border({ width: { top: 1 }, color: '#33FFB3CE' })
  }
}
