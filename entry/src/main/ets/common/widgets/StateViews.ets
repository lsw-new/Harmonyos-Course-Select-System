// 通用状态视图：Loading / Empty / Error
import { ElysiaTheme } from '../Theme';
import { AppFontSize } from '../constants/TextStyles';
import { AppSpacing } from '../constants/Dimensions';
import { AppIcon } from './AppIcon';

@Component
export struct LoadingState {
  @Prop tip: ResourceStr = $r('app.string.common_loading');

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
  @Prop icon: string = 'petal';
  @Prop title: ResourceStr = $r('app.string.common_empty');
  @Prop hint: string = '';

  build() {
    Column() {
      AppIcon({ name: this.icon, iconSize: 52, dim: true })
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
  @Prop message: ResourceStr = $r('app.string.common_load_failed');
  onRetry?: () => void;

  build() {
    Column() {
      AppIcon({ name: 'error', iconSize: 44 })
      Text(this.message)
        .fontSize(AppFontSize.bodyLarge)
        .fontColor(ElysiaTheme.INK_SOFT)
        .margin({ top: AppSpacing.md })
        .textAlign(TextAlign.Center)
      Button($r('app.string.common_reload'))
        .fontSize(AppFontSize.body)
        .fontColor(ElysiaTheme.ROSE_700)
        .backgroundColor(ElysiaTheme.glass())
        .border({ width: 1, color: ElysiaTheme.hairline() })
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
