// 通用组件库 · Elysia
import { ElysiaTheme, Gradients } from './Theme';

class TabDef {
  id: string = '';
  label: string = '';
  icon: string = '';
  constructor(id: string, label: string, icon: string) {
    this.id = id;
    this.label = label;
    this.icon = icon;
  }
}

// 玫瑰图标
@Component
export struct RoseIcon {
  @Prop iconSize: number = 18;
  @Prop color: string = ElysiaTheme.ROSE_500;

  build() {
    Stack() {
      Text('✿')
        .fontSize(this.iconSize)
        .fontColor(this.color)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }
}

// 星芒
@Component
export struct Sparkle {
  @Prop iconSize: number = 12;
  @Prop color: string = ElysiaTheme.GOLD_500;
  build() {
    Text('✦')
      .fontSize(this.iconSize)
      .fontColor(this.color)
  }
}

// É 字母 Monogram 圆章
@Component
export struct Monogram {
  @Prop iconSize: number = 56;
  build() {
    Stack() {
      Text('É')
        .fontSize(this.iconSize * 0.5)
        .fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700)
        .fontFamily(ElysiaTheme.FONT_DISPLAY)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .borderRadius(this.iconSize / 2)
    .linearGradient({
      angle: 220,
      colors: [
        [ElysiaTheme.ROSE_200, 0.0],
        [ElysiaTheme.ROSE_100, 0.3],
        [ElysiaTheme.LAV_200, 0.6],
        [ElysiaTheme.CREAM_100, 0.85],
        [ElysiaTheme.ROSE_200, 1.0]
      ]
    })
    .shadow({ radius: 12, color: '#40F2709C', offsetX: 0, offsetY: 6 })
  }
}

// 顶栏（含返回 + 中间标题）
@Component
export struct TopBar {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop showBack: boolean = true;
  onBack?: () => void;

  build() {
    Row() {
      if (this.showBack) {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize(20).fontColor(ElysiaTheme.ROSE_700)
        }
        .width(34).height(34)
        .backgroundColor('#A6FFFFFF')
        .border({ width: 1, color: '#99FFB3CE' })
        .onClick(() => { if (this.onBack) this.onBack(); })
      } else {
        Blank().width(34)
      }

      Column() {
        Text(this.title)
          .fontSize(18)
          .fontStyle(FontStyle.Italic)
          .fontColor(ElysiaTheme.ROSE_700)
          .fontFamily(ElysiaTheme.FONT_DISPLAY)
        Text(this.subtitle)
          .fontSize(11)
          .fontColor(ElysiaTheme.INK_SOFT)
          .margin({ top: 2 })
          .letterSpacing(3)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Blank().width(34)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }
}

// 玫瑰分隔线
@Component
export struct RoseDivider {
  @Prop label: string = '';
  build() {
    Row() {
      Divider()
        .layoutWeight(1)
        .strokeWidth(1)
        .color('#99FFB3CE')
        .opacity(0.6)
      Row() {
        RoseIcon({ iconSize: 10 })
        Text(this.label)
          .fontSize(10)
          .fontColor(ElysiaTheme.ROSE_500)
          .letterSpacing(2)
          .margin({ left: 6, right: 6 })
          .textCase(TextCase.UpperCase)
        RoseIcon({ iconSize: 10 })
      }
      Divider()
        .layoutWeight(1)
        .strokeWidth(1)
        .color('#99FFB3CE')
        .opacity(0.6)
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 14, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }
}

// 主按钮
@Component
export struct PrimaryButton {
  @Prop text: string = '';
  onTap?: () => void;
  build() {
    Button(this.text)
      .height(46)
      .width('100%')
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .backgroundColor(Color.Transparent)
      .linearGradient({
        angle: 135,
        colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]]
      })
      .borderRadius(999)
      .shadow({ radius: 18, color: '#B3F2709C', offsetX: 0, offsetY: 10 })
      .onClick(() => { if (this.onTap) this.onTap(); })
  }
}

// 副按钮
@Component
export struct GhostButton {
  @Prop text: string = '';
  onTap?: () => void;
  build() {
    Button(this.text)
      .height(42)
      .width('100%')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(ElysiaTheme.ROSE_700)
      .backgroundColor('#B3FFFFFF')
      .border({ width: 1, color: '#99FFB3CE' })
      .borderRadius(999)
      .onClick(() => { if (this.onTap) this.onTap(); })
  }
}

// 输入框
@Component
export struct ElysiaInput {
  @Prop placeholder: string = '';
  @Link value: string;
  @Prop secure: boolean = false;
  @Prop leadingIcon: string = '';

  build() {
    Stack({ alignContent: Alignment.Start }) {
      TextInput({ placeholder: this.placeholder, text: this.value })
        .type(this.secure ? InputType.Password : InputType.Normal)
        .height(46)
        .fontSize(13)
        .fontColor(ElysiaTheme.INK)
        .placeholderColor(ElysiaTheme.INK_MUTE)
        .backgroundColor('#CCFFFFFF')
        .border({ width: 1, color: '#80FFB3CE' })
        .borderRadius(14)
        .padding({ left: this.leadingIcon ? 38 : 14, right: 14 })
        .onChange((v) => { this.value = v; })
      if (this.leadingIcon) {
        Text(this.leadingIcon)
          .fontSize(14)
          .fontColor(ElysiaTheme.ROSE_600)
          .position({ x: 14, y: 16 })
      }
    }
    .width('100%')
  }
}

// 圆角卡片
@Component
export struct GlowCard {
  @BuilderParam content?: () => void;
  @Prop pad: number = 14;

  build() {
    Column() {
      if (this.content) {
        this.content();
      }
    }
    .width('100%')
    .padding(this.pad)
    .backgroundColor(ElysiaTheme.SURFACE)
    .borderRadius(22)
    .border({ width: 1, color: '#66FFB3CE' })
    .shadow({ radius: 16, color: '#1FD85487', offsetX: 0, offsetY: 4 })
  }
}

// 标签 pill
@Component
export struct Pill {
  @Prop text: string = '';
  @Prop bg: string = '';
  @Prop color: string = '';

  build() {
    Text(this.text)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.color || ElysiaTheme.ROSE_700)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(this.bg || '#FFE4EE')
      .border({ width: 1, color: '#B3FFB3CE' })
      .borderRadius(999)
  }
}

// 底部 TabBar
@Component
export struct ElysiaTabBar {
  @Prop active: string = 'home';

  private tabs: TabDef[] = [
    new TabDef('home', 'Home', '⌂'),
    new TabDef('mine', 'Mine', '○'),
    new TabDef('eval', 'Eval', '✦'),
    new TabDef('pra', 'Prac', '❀'),
    new TabDef('pub', 'Pub', '✧')
  ];

  build() {
    Row() {
      ForEach(this.tabs, (tab: TabDef) => {
        Column() {
          Text(tab.icon)
            .fontSize(20)
            .fontColor(tab.id === this.active ? ElysiaTheme.ROSE_600 : ElysiaTheme.INK_MUTE)
          Text(tab.label)
            .fontSize(11)
            .fontStyle(FontStyle.Italic)
            .fontColor(tab.id === this.active ? ElysiaTheme.ROSE_600 : ElysiaTheme.INK_MUTE)
            .margin({ top: 2 })
            .fontFamily(ElysiaTheme.FONT_DISPLAY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      })
    }
    .width('100%')
    .height(72)
    .padding({ top: 10, bottom: 18, left: 14, right: 14 })
    .backgroundColor('#F2FFF6FA')
    .backdropBlur(8)
    .position({ x: 0, y: '100%' })
    .translate({ y: -72 })
  }
}
