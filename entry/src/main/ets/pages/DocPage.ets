// 协议 / 隐私文档 · 按 params.type 区分（公共页，无需守卫）
import { ElysiaTheme } from '../common/Theme';
import { TopBar } from '../common/Components';
import { AppRoute } from '../app/AppRoute';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

class DocSection {
  heading: string = '';
  body: string = '';
  constructor(heading: string, body: string) {
    this.heading = heading;
    this.body = body;
  }
}

@Entry
@Component
struct DocPage {
  @State docType: string = 'agreement';
  @StorageProp('darkMode') darkMode: boolean = false;

  aboutToAppear(): void {
    this.docType = AppRoute.getParam<string>('type', 'agreement');
  }

  private isAgreement(): boolean {
    return this.docType !== 'privacy';
  }

  private docTitle(): string {
    return this.isAgreement() ? '用户协议' : '隐私政策';
  }

  private docSubtitle(): string {
    return this.isAgreement() ? '用 户 协 议' : '隐 私 政 策';
  }

  private agreementSections(): DocSection[] {
    return [
      new DocSection('一、协议的接受与适用',
        '欢迎使用 Elysia 教学管理系统（以下简称「本系统」）。本协议是您与本系统运营方之间就使用本系统所订立的约定。当您注册、登录或以任何方式使用本系统时，即表示您已充分阅读、理解并同意接受本协议的全部内容。若您不同意本协议，请停止使用本系统。'),
      new DocSection('二、账户与登录',
        '您应使用学校统一身份认证或经授权的账号登录本系统，并对账号下的全部操作负责。请妥善保管登录凭据，不得将账号转借、出租或以其他方式提供给第三方。如发现账号被盗用或存在其他安全隐患，应立即修改密码并联系管理员。'),
      new DocSection('三、用户行为规范',
        '您承诺在使用本系统过程中遵守国家法律法规及学校相关管理规定，不得利用本系统从事任何违法违规或损害他人合法权益的行为，包括但不限于发布不当言论、上传违规内容、干扰系统正常运行、未经授权访问他人数据等。'),
      new DocSection('四、教务数据的使用',
        '本系统中的课表、成绩、选课、考试、评教、请假等教务数据，仅用于您本人的学习与教务管理。您应确保提交信息的真实、准确、完整；因填报信息不实导致的后果，由您自行承担。'),
      new DocSection('五、知识产权',
        '本系统所包含的界面设计、图标、文字、程序代码及其他内容的知识产权均归运营方或相应权利人所有。未经书面许可，您不得对上述内容进行复制、修改、传播或用于商业用途。'),
      new DocSection('六、服务的变更与中断',
        '为保障系统稳定与安全，运营方可能对本系统进行升级、维护或功能调整，并尽量提前通知。因系统维护、网络故障、不可抗力等原因导致服务暂时中断的，运营方不承担由此产生的直接或间接责任。'),
      new DocSection('七、免责声明',
        '在法律允许的范围内，对于因使用或无法使用本系统而造成的任何损失，运营方不承担超出法律规定范围的责任。最终的教务结果以学校教务部门的正式记录为准。'),
      new DocSection('八、协议的修改',
        '运营方有权根据法律法规及业务需要适时修订本协议，修订后的协议将在本系统内公布。若您在协议修订后继续使用本系统，即视为接受修订后的协议。')
    ];
  }

  private privacySections(): DocSection[] {
    return [
      new DocSection('一、引言',
        'Elysia 教学管理系统（以下简称「本系统」）非常重视您的个人信息与隐私保护。本政策旨在向您说明我们如何收集、使用、存储与保护您的信息，以及您所享有的相关权利。请您在使用本系统前仔细阅读本政策。'),
      new DocSection('二、我们收集的信息',
        '为向您提供教务服务，我们可能收集以下信息：身份信息（如姓名、学号、学院与班级）、账户信息（如登录凭据）、以及您在使用过程中产生的教务数据（如课表、成绩、选课、考试、评教与请假记录）。我们仅收集实现相应功能所必需的信息。'),
      new DocSection('三、信息的使用',
        '我们将收集的信息用于：完成身份核验与登录、展示与管理您的教务数据、发送与教学相关的通知提醒、以及改进系统的稳定性与体验。未经您的同意，我们不会将上述信息用于本政策未载明的其他目的。'),
      new DocSection('四、信息的存储与安全',
        '我们采取符合行业标准的安全措施保护您的信息，包括访问控制、传输加密与权限隔离等，以防止信息被未经授权地访问、泄露或篡改。您的本地偏好设置（如主题、字体大小、通知开关）仅保存在本设备中。'),
      new DocSection('五、信息的共享与披露',
        '我们不会向第三方出售您的个人信息。仅在以下情形下我们可能共享必要信息：获得您的明确同意、为完成教务流程需与学校相关部门共享、或依据法律法规及主管机关的要求进行披露。'),
      new DocSection('六、您的权利',
        '您有权访问、更正本人的个人信息，并可在符合规定的前提下申请删除或注销账户。您也可以在系统设置中管理通知与隐私相关的偏好。我们将在合理期限内响应您的请求。'),
      new DocSection('七、未成年人保护',
        '若您是未成年人，请在监护人的指导下使用本系统并提交个人信息。我们将依据法律法规对未成年人的个人信息给予特别保护。'),
      new DocSection('八、政策的更新与联系方式',
        '我们可能适时更新本隐私政策，更新内容将在本系统内公布。如您对本政策或个人信息保护有任何疑问，可通过 support@elysia.edu 与我们联系。')
    ];
  }

  private sections(): DocSection[] {
    return this.isAgreement() ? this.agreementSections() : this.privacySections();
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient(this.darkMode) })

      Column() {
        SafeTop()
        TopBar({ title: this.docTitle(), subtitle: this.docSubtitle(), onBack: () => { AppRoute.back(); } })

        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 6 }) {
              Text(this.docTitle())
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              Text('生效日期：2026 年 5 月 29 日 · 版本 V1.0.0')
                .fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft(this.darkMode) })

            Column({ space: 14 }) {
              ForEach(this.sections(), (sec: DocSection) => {
                this.SectionBlock(sec)
              }, (sec: DocSection) => sec.heading)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft(this.darkMode) })

            Text('如对以上条款有疑问，请联系 support@elysia.edu')
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE)
              .width('100%').textAlign(TextAlign.Center).margin({ top: 4 })

            SafeBottom()
          }.padding({ left: 16, right: 16 })
        }.scrollBar(BarState.Off).layoutWeight(1)
      }
    }.width('100%').height('100%')
  }

  @Builder SectionBlock(sec: DocSection) {
    Column({ space: 6 }) {
      Text(sec.heading)
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.ROSE_700)
      Text(sec.body)
        .fontSize(13).fontColor(ElysiaTheme.INK_SOFT).lineHeight(22)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
