// 图标系统 · Elysia
// 将设计交付的 SVG 线性图标（玫瑰描边 #A93C68 + 玫瑰点缀 #F2709C）
// 统一封装为 AppIcon 组件，页面通过语义键名引用，避免散落的 emoji / 字形。
//
// 资源位于 entry/src/main/resources/base/media/ic_*.svg
// 键名即去掉 ic_ 前缀的文件名（连字符转下划线）。

export class AppIcons {
  // 语义键名 -> 媒体资源（$r 需为字符串字面量，故在此集中登记）
  static readonly map: Record<string, Resource> = {
    'approve': $r('app.media.ic_approve'),
    'back': $r('app.media.ic_back'),
    'bell': $r('app.media.ic_bell'),
    'book': $r('app.media.ic_book'),
    'calendar': $r('app.media.ic_calendar'),
    'camera': $r('app.media.ic_camera'),
    'chat': $r('app.media.ic_chat'),
    'check': $r('app.media.ic_check'),
    'close': $r('app.media.ic_close'),
    'course': $r('app.media.ic_course'),
    'dashboard': $r('app.media.ic_dashboard'),
    'download': $r('app.media.ic_download'),
    'edit': $r('app.media.ic_edit'),
    'error': $r('app.media.ic_error'),
    'evaluation': $r('app.media.ic_evaluation'),
    'exam': $r('app.media.ic_exam'),
    'eye': $r('app.media.ic_eye'),
    'eye_off': $r('app.media.ic_eye_off'),
    'feedback': $r('app.media.ic_feedback'),
    'file': $r('app.media.ic_file'),
    'filter': $r('app.media.ic_filter'),
    'forward': $r('app.media.ic_forward'),
    'grades': $r('app.media.ic_grades'),
    'heart': $r('app.media.ic_heart'),
    'home': $r('app.media.ic_home'),
    'image': $r('app.media.ic_image'),
    'info': $r('app.media.ic_info'),
    'leave': $r('app.media.ic_leave'),
    'location': $r('app.media.ic_location'),
    'lock': $r('app.media.ic_lock'),
    'madame': $r('app.media.ic_madame'),
    'mail': $r('app.media.ic_mail'),
    'menu': $r('app.media.ic_menu'),
    'mine': $r('app.media.ic_mine'),
    'more': $r('app.media.ic_more'),
    'notice': $r('app.media.ic_notice'),
    'petal': $r('app.media.ic_petal'),
    'phone': $r('app.media.ic_phone'),
    'pin': $r('app.media.ic_pin'),
    'plus': $r('app.media.ic_plus'),
    'practice': $r('app.media.ic_practice'),
    'public': $r('app.media.ic_public'),
    'qr': $r('app.media.ic_qr'),
    'refresh': $r('app.media.ic_refresh'),
    'rose': $r('app.media.ic_rose'),
    'roster': $r('app.media.ic_roster'),
    'scan': $r('app.media.ic_scan'),
    'schedule': $r('app.media.ic_schedule'),
    'search': $r('app.media.ic_search'),
    'selection': $r('app.media.ic_selection'),
    'send': $r('app.media.ic_send'),
    'settings': $r('app.media.ic_settings'),
    'sort': $r('app.media.ic_sort'),
    'sparkle': $r('app.media.ic_sparkle'),
    'star': $r('app.media.ic_star'),
    'students': $r('app.media.ic_students'),
    'success': $r('app.media.ic_success'),
    'tag': $r('app.media.ic_tag'),
    'time': $r('app.media.ic_time'),
    'trash': $r('app.media.ic_trash'),
    'unlock': $r('app.media.ic_unlock'),
    'upload': $r('app.media.ic_upload'),
    'wallet': $r('app.media.ic_wallet'),
    'warning': $r('app.media.ic_warning')
  };

  // 按键名取资源，未登记时回退到玫瑰花瓣，避免渲染空白。
  static res(name: string): Resource {
    const r: Resource | undefined = AppIcons.map[name];
    return r !== undefined ? r : $r('app.media.ic_petal');
  }
}

// 通用图标：以语义键名渲染设计图标。
//   name  语义键名（见 AppIcons.map）
//   size  边长（正方形，单位 vp）
//   dim   置灰/弱化（用于未选中态等），保持图标本身配色仅降低不透明度。
//   mLeft / mRight / mTop 行内间距（避免在自定义组件上链式调用通用属性）。
@Component
export struct AppIcon {
  @Prop name: string = 'petal';
  @Prop iconSize: number = 24;
  @Prop dim: boolean = false;
  @Prop mLeft: number = 0;
  @Prop mRight: number = 0;
  @Prop mTop: number = 0;

  build() {
    Image(AppIcons.res(this.name))
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
      .opacity(this.dim ? 0.38 : 1)
      .margin({ left: this.mLeft, right: this.mRight, top: this.mTop })
      .draggable(false)
  }
}
