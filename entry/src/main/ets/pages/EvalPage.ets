// 量化评教 · Evaluation（接入 EvaluationRepository + 内联问卷）
import { ElysiaTheme } from '../common/Theme';
import { TopBar } from '../common/Components';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { StudentTabBar } from '../common/widgets/TabBars';
import { AppIcon } from '../common/widgets/AppIcon';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { EvaluationRepository } from '../repositories/EvaluationRepository';
import { EvalAdminRepository } from '../repositories/EvalAdminRepository';
import {
  EvaluationTask, EvaluationQuestionnaire, EvaluationQuestion,
  EvaluationOption, EvaluationAnswer
} from '../models/Evaluation';

// 单题作答（与问卷题目按下标一一对应）
class QAnswer {
  questionId: string = '';
  type: string = '';
  rating: number = 0;
  singleId: string = '';
  multiIds: string[] = [];
  text: string = '';
}

@Component
struct EvalPage {
  @StorageProp('breakpoint') bp: string = 'sm';
  @State tasks: EvaluationTask[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  // 评教期总开关：管理员在评教管理中关闭后，本页显示「未开放」整页状态
  @State periodOpen: boolean = true;

  // 内联问卷弹层
  @State sheetOpen: boolean = false;
  @State activeTaskId: string = '';
  @State activeTaskName: string = '';
  @State questionnaire?: EvaluationQuestionnaire = undefined;
  @State qLoading: boolean = false;
  @State qError: string = '';
  @State submitting: boolean = false;
  @State answers: QAnswer[] = [];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.Eval)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    AppRoute.showLoading();
    this.errorMsg = '';
    // 先查评教期总开关：未开放时不拉任务，直接进入「未开放」整页状态
    EvalAdminRepository.get().isPeriodOpen()
      .then((open: boolean): Promise<EvaluationTask[] | undefined> => {
        this.periodOpen = open;
        if (!open) {
          this.tasks = [];
          this.loading = false;
          return Promise.resolve<EvaluationTask[] | undefined>(undefined);
        }
        return EvaluationRepository.get().getTasks();
      })
      .then((list: EvaluationTask[] | undefined) => {
        if (list !== undefined) {
          this.tasks = list;
          this.loading = false;
        }
      })
      .catch((e: object) => {
        this.errorMsg = e instanceof Error ? e.message : '加载失败';
        this.loading = false;
      });
  }

  private doneCount(): number {
    let c = 0;
    this.tasks.forEach((t: EvaluationTask) => { if (t.status === 'submitted') c++; });
    return c;
  }

  private openSheet(task: EvaluationTask): void {
    this.activeTaskId = task.id;
    this.activeTaskName = task.courseName;
    this.sheetOpen = true;
    this.qError = '';
    this.questionnaire = undefined;
    this.answers = [];
    this.loadQuestionnaire();
  }

  private loadQuestionnaire(): void {
    this.qLoading = true;
    this.qError = '';
    EvaluationRepository.get().getQuestionnaire(this.activeTaskId)
      .then((q: EvaluationQuestionnaire) => {
        this.questionnaire = q;
        const arr: QAnswer[] = [];
        q.questions.forEach((item: EvaluationQuestion) => {
          const a = new QAnswer();
          a.questionId = item.id;
          a.type = item.type;
          arr.push(a);
        });
        this.answers = arr;
        this.qLoading = false;
      })
      .catch((e: object) => {
        this.qError = e instanceof Error ? e.message : '问卷加载失败';
        this.qLoading = false;
      });
  }

  private closeSheet(): void {
    this.sheetOpen = false;
    this.questionnaire = undefined;
    this.answers = [];
    this.submitting = false;
  }

  private setRating(i: number, n: number): void {
    this.answers[i].rating = n;
    this.answers = this.answers.slice();
  }

  private setSingle(i: number, id: string): void {
    this.answers[i].singleId = id;
    this.answers = this.answers.slice();
  }

  private toggleMulti(i: number, id: string): void {
    const a = this.answers[i];
    const idx = a.multiIds.indexOf(id);
    if (idx >= 0) {
      a.multiIds.splice(idx, 1);
    } else {
      a.multiIds.push(id);
    }
    this.answers = this.answers.slice();
  }

  private setText(i: number, v: string): void {
    this.answers[i].text = v;
    this.answers = this.answers.slice();
  }

  private isSingleSelected(i: number, optId: string): boolean {
    return this.answers[i].singleId === optId;
  }

  private isMultiSelected(i: number, optId: string): boolean {
    return this.answers[i].multiIds.indexOf(optId) >= 0;
  }

  private submit(): void {
    if (this.submitting) return;
    const qn = this.questionnaire;
    if (qn === undefined) return;
    const qs: EvaluationQuestion[] = qn.questions;
    const out: EvaluationAnswer[] = [];
    for (let i = 0; i < qs.length; i++) {
      const q = qs[i];
      const a = this.answers[i];
      if (q.type === 'rating') {
        if (a.rating > 0) {
          out.push({ questionId: q.id, value: a.rating });
        } else if (q.required) {
          this.qError = `请完成必答题：${q.title}`;
          return;
        }
      } else if (q.type === 'single') {
        if (a.singleId.length > 0) {
          out.push({ questionId: q.id, value: a.singleId });
        } else if (q.required) {
          this.qError = `请完成必答题：${q.title}`;
          return;
        }
      } else if (q.type === 'multiple') {
        if (a.multiIds.length > 0) {
          out.push({ questionId: q.id, value: a.multiIds });
        } else if (q.required) {
          this.qError = `请完成必答题：${q.title}`;
          return;
        }
      } else {
        if (a.text.trim().length > 0) {
          out.push({ questionId: q.id, value: a.text.trim() });
        } else if (q.required) {
          this.qError = `请完成必答题：${q.title}`;
          return;
        }
      }
    }
    if (out.length === 0) {
      this.qError = '请至少回答一题';
      return;
    }
    this.qError = '';
    this.submitting = true;
    EvaluationRepository.get().submit(this.activeTaskId, out)
      .then((_ok: boolean) => {
        this.submitting = false;
        this.closeSheet();
        this.loadData();
      })
      .catch((e: object) => {
        this.submitting = false;
        this.qError = e instanceof Error ? e.message : '提交失败';
      });
  }

  private statusLabel(s: string): string {
    if (s === 'open') return '去评教';
    if (s === 'submitted') return '已提交';
    return '未开放';
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: ElysiaTheme.pageGradient()
        })

      Column() {
        SafeTop()
        TopBar({ title: $r('app.string.eval_title'), subtitle: $r('app.string.eval_subtitle'), onBack: () => AppRoute.back() })

        Column() {
          if (this.loading) {
            LoadingState({ tip: $r('app.string.eval_loading') })
          } else if (this.errorMsg.length > 0) {
            ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
          } else if (!this.periodOpen) {
            this.ClosedState()
          } else {
            Scroll() {
              Column() {
                this.ProgressHero()
                if (this.tasks.length === 0) {
                  EmptyState({ icon: 'evaluation', title: $r('app.string.eval_empty') })
                } else {
                  Column({ space: 10 }) {
                    ForEach(this.tasks, (task: EvaluationTask) => {
                      this.TaskCard(task)
                    }, (task: EvaluationTask) => task.id)
                  }
                  .margin({ top: 14, bottom: 30 })
                }
                SafeBottom()
              }
              .padding({ left: 16, right: 16 })
            }
            .scrollBar(BarState.Off)
            .layoutWeight(1)
          }
        }
        .width('100%').layoutWeight(1)

        StudentTabBar({
          active: 'eval',
          onTap: (id: string, route: string) => {
            if (id !== 'eval') AppRoute.go(route, { replace: true });
          }
        })
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })

      if (this.sheetOpen) {
        this.QuestionnaireSheet()
      }
    }
    .width('100%').height('100%')
  }

  // 评教期未开放：整页提示态（管理员在「评教管理」开放评教期后，刷新即可进入）
  @Builder ClosedState() {
    Column() {
      Stack() {
        AppIcon({ name: 'evaluation', iconSize: 34, dim: true })
      }
      .width(84).height(84).borderRadius(42)
      .backgroundColor(ElysiaTheme.glassSoft())
      .border({ width: 1, color: ElysiaTheme.hairline() })

      Text($r('app.string.eval_closed_title'))
        .fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor(ElysiaTheme.INK).margin({ top: 16 })
      Text($r('app.string.eval_closed_sub'))
        .fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
        .textAlign(TextAlign.Center).lineHeight(20)
        .margin({ top: 8 }).padding({ left: 32, right: 32 })

      Button($r('app.string.eval_closed_refresh'))
        .height(36).fontSize(12).fontWeight(FontWeight.Medium)
        .padding({ left: 20, right: 20 })
        .fontColor(ElysiaTheme.ROSE_700)
        .backgroundColor(ElysiaTheme.glassSoft())
        .border({ width: 1, color: ElysiaTheme.hairline() })
        .borderRadius(999)
        .margin({ top: 18 })
        .onClick(() => this.loadData())
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder ProgressHero() {
    Column() {
      Text($r('app.string.eval_hero_title')).fontSize(18).fontStyle(FontStyle.Italic)
        .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
      Text($r('app.string.eval_hero_sub'))
        .fontSize(11).fontColor(ElysiaTheme.INK_SOFT).lineHeight(18).margin({ top: 6 })
      Row() {
        Text(`${this.doneCount()} / ${this.tasks.length}`)
          .fontSize(28).fontStyle(FontStyle.Italic)
          .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
        Text($r('app.string.eval_done')).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
      }.alignItems(VerticalAlign.Bottom).margin({ top: 10 })
      Stack({ alignContent: Alignment.Start }) {
        Stack().width('100%').height(6).backgroundColor(ElysiaTheme.glassSoft()).borderRadius(3)
        Stack()
          .width(this.tasks.length === 0 ? '0%' : `${(this.doneCount() / this.tasks.length) * 100}%`)
          .height(6).borderRadius(3)
          .linearGradient({ angle: 90, colors: [[ElysiaTheme.ROSE_500, 0], [ElysiaTheme.LAV_500, 1]] })
      }.margin({ top: 8 })
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .padding(16).borderRadius(22)
    .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_200, 0], [ElysiaTheme.LAV_200, 1]] })
  }

  @Builder TaskCard(task: EvaluationTask) {
    Column() {
      Row() {
        Stack() {
          Text(task.teacherName.slice(0, 1)).fontSize(14).fontStyle(FontStyle.Italic)
            .fontColor(ElysiaTheme.ROSE_700).fontFamily(ElysiaTheme.FONT_DISPLAY)
        }
        .width(36).height(36).borderRadius(18)
        .linearGradient({ angle: 135, colors: [[ElysiaTheme.ROSE_100, 0], [ElysiaTheme.LAV_200, 1]] })
        Column() {
          Text(task.courseName).fontSize(12.5).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
          Text(`${task.teacherName} 老师 · ${task.questionnaireName}`)
            .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 }).maxLines(1)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
        Button(this.statusLabel(task.status))
          .height(28).fontSize(10).fontWeight(FontWeight.Bold).padding({ left: 12, right: 12 })
          .fontColor(task.status === 'open' ? Color.White : (task.status === 'submitted' ? '#3F7A4A' : ElysiaTheme.INK_MUTE))
          .backgroundColor(task.status === 'open' ? Color.Transparent : ElysiaTheme.glassSoft())
          .linearGradient(task.status === 'open'
            ? { angle: 135, colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]] }
            : { angle: 0, colors: [['#00FFFFFF', 0], ['#00FFFFFF', 1]] })
          .border({ width: task.status === 'open' ? 0 : 1, color: ElysiaTheme.hairline() })
          .borderRadius(999)
          .enabled(task.status === 'open')
          .onClick(() => { if (task.status === 'open') this.openSheet(task); })
      }
    }
    .width('100%').padding(14)
    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(22)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .shadow({ radius: 14, color: '#1FD85487', offsetX: 0, offsetY: 4 })
  }

  @Builder QuestionnaireSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(ElysiaTheme.scrim())
        .onClick(() => this.closeSheet())

      Column() {
        Row() {
          Column() {
            Text(this.activeTaskName).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
            Text(this.questionnaire !== undefined ? this.questionnaire!.title : $r('app.string.eval_questionnaire'))
              .fontSize(10).fontColor(ElysiaTheme.INK_MUTE).margin({ top: 2 }).maxLines(1)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button({ type: ButtonType.Circle }) { AppIcon({ name: 'close', iconSize: 16 }) }
            .width(32).height(32).backgroundColor(ElysiaTheme.glassSoft())
            .border({ width: 1, color: ElysiaTheme.hairline() })
            .accessibilityText($r('app.string.common_close'))
            .onClick(() => this.closeSheet())
        }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 10 })

        if (this.qLoading) {
          Column() { LoadingState({ tip: $r('app.string.eval_q_loading') }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.questionnaire === undefined) {
          Column() { ErrorState({ message: this.qError.length > 0 ? this.qError : '问卷加载失败', onRetry: () => this.loadQuestionnaire() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              if (this.questionnaire!.description !== undefined) {
                Text(this.questionnaire!.description).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).width('100%')
              }
              ForEach(this.questionnaire!.questions, (q: EvaluationQuestion, i?: number) => {
                this.QuestionItem(q, i ?? 0)
              }, (q: EvaluationQuestion) => q.id)

              if (this.qError.length > 0) {
                Text(this.qError).fontSize(12).fontColor(ElysiaTheme.ROSE_ACCENT).width('100%')
              }

              Button(this.submitting ? $r('app.string.common_submitting') : $r('app.string.eval_submit'))
                .width('100%').height(46).fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(Color.White).backgroundColor(Color.Transparent)
                .linearGradient({ angle: 135, colors: [['#FF9FBE', 0], [ElysiaTheme.ROSE_500, 1]] })
                .borderRadius(999)
                .enabled(!this.submitting)
                .onClick(() => this.submit())
              Blank().height(30)
            }.padding({ left: 18, right: 18, top: 4 })
          }.scrollBar(BarState.Off).layoutWeight(1)
        }
      }
      .width('100%').height('86%')
      .backgroundColor(ElysiaTheme.CREAM_50)
      .borderRadius({ topLeft: 28, topRight: 28 })
      .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    }
    .width('100%').height('100%')
  }

  @Builder QuestionItem(q: EvaluationQuestion, i: number) {
    Column() {
      Row() {
        if (q.required) {
          Text('*').fontSize(13).fontColor(ElysiaTheme.ROSE_ACCENT).margin({ right: 4 })
        }
        Text(q.title).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
      }.width('100%')

      if (q.type === 'rating') {
        Row({ space: 10 }) {
          ForEach([1, 2, 3, 4, 5], (n: number) => {
            Stack() {
              AppIcon({ name: 'star', iconSize: 30, dim: this.answers[i].rating < n })
            }.onClick(() => this.setRating(i, n))
          }, (n: number) => `${q.id}-${n}`)
        }.margin({ top: 12 })
      } else if (q.type === 'single' && q.options !== undefined) {
        Column({ space: 8 }) {
          ForEach(q.options, (opt: EvaluationOption) => {
            this.OptionRow(i, opt, false)
          }, (opt: EvaluationOption) => opt.id)
        }.margin({ top: 10 })
      } else if (q.type === 'multiple' && q.options !== undefined) {
        Column({ space: 8 }) {
          ForEach(q.options, (opt: EvaluationOption) => {
            this.OptionRow(i, opt, true)
          }, (opt: EvaluationOption) => opt.id)
        }.margin({ top: 10 })
      } else if (q.type === 'text') {
        TextArea({ placeholder: $r('app.string.eval_input_ph'), text: this.answers[i].text })
          .height(80).fontSize(13).fontColor(ElysiaTheme.INK)
          .backgroundColor(ElysiaTheme.glass()).border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
          .margin({ top: 10 })
          .maxLength(q.maxLength ?? 200)
          .onChange((v: string) => this.setText(i, v))
      }
    }
    .width('100%').padding(14)
    .backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder OptionRow(i: number, opt: EvaluationOption, multi: boolean) {
    Row() {
      Stack() {
        if (multi ? this.isMultiSelected(i, opt.id) : this.isSingleSelected(i, opt.id)) {
          AppIcon({ name: multi ? 'check' : 'approve', iconSize: 14 })
        }
      }
      .width(20).height(20).borderRadius(multi ? 6 : 10)
      .backgroundColor((multi ? this.isMultiSelected(i, opt.id) : this.isSingleSelected(i, opt.id)) ? ElysiaTheme.ROSE_100 : ElysiaTheme.glass())
      .border({ width: 1, color: (multi ? this.isMultiSelected(i, opt.id) : this.isSingleSelected(i, opt.id)) ? ElysiaTheme.ROSE_500 : ElysiaTheme.hairline() })
      Text(opt.label).fontSize(12).fontColor(ElysiaTheme.INK).margin({ left: 10 }).layoutWeight(1)
    }
    .width('100%').padding({ top: 6, bottom: 6 })
    .onClick(() => { if (multi) { this.toggleMulti(i, opt.id); } else { this.setSingle(i, opt.id); } })
  }
}

// 系统路由表构建函数
@Builder
export function EvalPageBuilder() {
  NavDestination() {
    EvalPage()
  }
  .hideTitleBar(true)
}
