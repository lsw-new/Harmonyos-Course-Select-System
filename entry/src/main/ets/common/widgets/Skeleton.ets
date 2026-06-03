// 骨架屏：加载时用占位块替代“正在加载”文字，loading→content 切换不跳动。
// 列表页：if (this.loading) { SkeletonList({ count: 5 }) } else if (err) {...} else { 真实列表 }
import { ElysiaTheme } from '../Theme';

@Component
export struct SkeletonBlock {
  @Prop skWidth: Length = '100%';
  @Prop skHeight: number = 14;
  @Prop skRadius: number = 7;

  build() {
    Row()
      .width(this.skWidth)
      .height(this.skHeight)
      .borderRadius(this.skRadius)
      .backgroundColor(ElysiaTheme.glass())
      .opacity(0.75)
  }
}

@Component
export struct SkeletonCard {
  build() {
    Column({ space: 10 }) {
      SkeletonBlock({ skWidth: '58%', skHeight: 18 })
      SkeletonBlock({ skWidth: '100%', skHeight: 12 })
      SkeletonBlock({ skWidth: '82%', skHeight: 12 })
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(ElysiaTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
  }
}

@Component
export struct SkeletonList {
  @Prop count: number = 4;

  private range(): number[] {
    const arr: number[] = [];
    for (let i = 0; i < this.count; i++) {
      arr.push(i);
    }
    return arr;
  }

  build() {
    Column({ space: 12 }) {
      ForEach(this.range(), (i: number) => {
        SkeletonCard()
      }, (i: number) => `sk-${i}`)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8 })
  }
}
