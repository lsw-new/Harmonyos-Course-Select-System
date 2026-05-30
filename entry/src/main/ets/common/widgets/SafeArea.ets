// 安全区占位组件 · Safe-area insets
// 顶部状态栏 / 底部手势指示条的避让高度由 EntryAbility 测量后写入 AppStorage，
// 此处以 @StorageProp 订阅 → 全屏(edge-to-edge)布局下各页面用它替代写死的 Blank(40)。
// 测量失败或尚未就绪时回退到默认值，最坏情况与旧版固定 40 一致。

@Component
export struct SafeTop {
  @StorageProp('safeTop') safeTop: number = 40;
  // 额外留白（少数页面顶部需要比状态栏更大的呼吸空间时使用）。
  @Prop extra: number = 0;

  build() {
    Blank().height(this.safeTop + this.extra)
  }
}

@Component
export struct SafeBottom {
  @StorageProp('safeBottom') safeBottom: number = 0;
  // 在手势指示条之上再留出的基础呼吸空间。
  @Prop extra: number = 16;

  build() {
    Blank().height(this.safeBottom + this.extra)
  }
}
