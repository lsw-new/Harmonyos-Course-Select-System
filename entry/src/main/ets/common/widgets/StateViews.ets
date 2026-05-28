// 通用状态视图：Loading / Empty / Error
import { ElysiaTheme } from '../Theme';
import { AppFontFamily, AppFontSize } from '../constants/TextStyles';
import { AppSpacing } from '../constants/Dimensions';

@Component
export struct LoadingState {
  @Prop tip: string = '加载中...';

  build() {
    Column() {
      LoadingProgress()
        .width(36).height(36)
        .color(ElysiaTheme.ROSE_500)
      Text(this.tip)
        .fontSize(AppFontSize.caption)
        .fontColor(ElysiaTheme.INK_SOFT)
        .margin({ top: AppSpacing.md })
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct EmptyState {
  @Prop icon: string = '✿';
  @Prop title: string = '暂无数据';
  @Prop hint: string = '';

  build() {
    Column() {
      Text(this.icon)
        .fontSize(48)
        .fontColor(ElysiaTheme.ROSE_300)
        .fontFamily(AppFontFamily.display)
      Text(this.title)
        .fontSize(AppFontSize.bodyLarge)
        .fontColor(ElysiaTheme.INK_SOFT)
        .margin({ top: AppSpacing.md })
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(AppFontSize.caption)
          .fontColor(ElysiaTheme.INK_MUTE)
          .margin({ top: AppSpacing.xs })
      }
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct ErrorState {
  @Prop message: string = '加载失败';
  onRetry?: () => void;

  build() {
    Column() {
      Text('✦')
        .fontSize(40)
        .fontColor(ElysiaTheme.ROSE_500)
      Text(this.message)
        .fontSize(AppFontSize.bodyLarge)
        .fontColor(ElysiaTheme.INK_SOFT)
        .margin({ top: AppSpacing.md })
        .textAlign(TextAlign.Center)
      Button('重新加载')
        .fontSize(AppFontSize.body)
        .fontColor(ElysiaTheme.ROSE_700)
        .backgroundColor('#B3FFFFFF')
        .border({ width: 1, color: '#99FFB3CE' })
        .borderRadius(999)
        .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        .height(36)
        .margin({ top: AppSpacing.lg })
        .onClick(() => { if (this.onRetry) this.onRetry(); })
    }
    .width('100%')
    .padding({ top: 60, bottom: 60, left: AppSpacing.lg, right: AppSpacing.lg })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
