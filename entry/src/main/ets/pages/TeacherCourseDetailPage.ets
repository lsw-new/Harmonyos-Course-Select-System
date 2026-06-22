// 教师端课程详情（roadmap #6）：学生名单 + 成绩录入（录入阶段，提交后管理端审核发布）。
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton } from '../common/Components';
import { TeacherRepository, TeacherGradeResult } from '../repositories/TeacherRepository';
import { TeacherCourseStudents, TeacherStudent, TeacherScoreInput, TeacherGradeDistribution } from '../models/Teacher';
import { HttpError } from '../common/http/HttpError';
import { LoadingState, ErrorState, EmptyState } from '../common/widgets/StateViews';
import { AppRoute, Routes } from '../app/AppRoute';
import { RouteLoadingOverlay } from '../common/widgets/RouteLoadingOverlay';
import { BreakpointManager } from '../common/widgets/Breakpoint';
import { Toast } from '../common/widgets/Feedback';
import { SafeTop, SafeBottom } from '../common/widgets/SafeArea';

interface EditRow {
  studentId: string;
  name: string;
  className: string;
  currentScore: string;
  input: string;
  status: string;
}

@Component
struct TeacherCourseDetailPage {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State courseName: string = '';
  @State className: string = '';
  @State rows: EditRow[] = [];
  @State distribution: TeacherGradeDistribution | null = null;
  private courseId: string = '';
  @StorageProp('breakpoint') bp: string = 'sm';

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.TeacherCourseDetail)) {
      return;
    }
    this.courseId = AppRoute.getParam<string>('courseId', '');
    this.courseName = AppRoute.getParam<string>('courseName', '课程');
    this.reload();
  }

  private scoreText(v: number | null): string {
    return v === null ? '' : `${v}`;
  }

  private reload(): void {
    this.loading = true;
    this.errorMsg = '';
    TeacherRepository.get().getCourseStudents(this.courseId).then((data: TeacherCourseStudents) => {
      this.className = data.teachingClassName;
      this.rows = data.students.map((s: TeacherStudent): EditRow => {
        const cur: string = this.scoreText(s.score);
        return {
          studentId: s.studentId,
          name: s.name,
          className: s.className,
          currentScore: cur,
          input: cur,
          status: s.status
        };
      });
      this.loading = false;
      // 成绩分布（次要信息，失败不影响名单）
      TeacherRepository.get().getGradeDistribution(this.courseId).then((d: TeacherGradeDistribution) => {
        this.distribution = d;
      }).catch(() => {});
    }).catch((e: object) => {
      this.loading = false;
      this.errorMsg = (e instanceof HttpError) ? (e as HttpError).message : '加载失败';
    });
  }

  @Builder DistBar(d: TeacherGradeDistribution) {
    Column({ space: 8 }) {
      Row() {
        Text('成绩分布').fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
        Text(d.total > 0 ? `均分 ${d.avgScore} · ${d.total} 人` : '暂无成绩').fontSize(12).fontColor(ElysiaTheme.ROSE_500)
      }.width('100%')
      if (d.total > 0) {
        Row() {
          if (d.excellent > 0) {
            Row().layoutWeight(d.excellent).height(14).backgroundColor('#5FB7A1')
          }
          if (d.good > 0) {
            Row().layoutWeight(d.good).height(14).backgroundColor('#8BC34A')
          }
          if (d.medium > 0) {
            Row().layoutWeight(d.medium).height(14).backgroundColor('#D9B675')
          }
          if (d.pass > 0) {
            Row().layoutWeight(d.pass).height(14).backgroundColor('#E89B5F')
          }
          if (d.fail > 0) {
            Row().layoutWeight(d.fail).height(14).backgroundColor(ElysiaTheme.ROSE_500)
          }
        }.width('100%').height(14).borderRadius(7).clip(true)
        Row() {
          Text(`优${d.excellent}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
          Text(`良${d.good}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
          Text(`中${d.medium}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
          Text(`及格${d.pass}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
          Text(`不及格${d.fail}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT).layoutWeight(1)
        }.width('100%')
      }
    }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(16).alignItems(HorizontalAlign.Start)
  }

  private updateInput(studentId: string, value: string): void {
    this.rows = this.rows.map((r: EditRow): EditRow => {
      if (r.studentId !== studentId) {
        return r;
      }
      return {
        studentId: r.studentId,
        name: r.name,
        className: r.className,
        currentScore: r.currentScore,
        input: value,
        status: r.status
      };
    });
  }

  // 收集合法（0-100）输入为打分项；非数字/越界忽略
  private collectScores(): TeacherScoreInput[] {
    const out: TeacherScoreInput[] = [];
    this.rows.forEach((r: EditRow) => {
      const text = r.input.trim();
      if (text.length === 0) {
        return;
      }
      const n = Number(text);
      if (Number.isFinite(n) && n >= 0 && n <= 100) {
        out.push({ studentId: r.studentId, score: n });
      }
    });
    return out;
  }

  private submit(): void {
    if (this.submitting) {
      return;
    }
    const scores = this.collectScores();
    if (scores.length === 0) {
      Toast.show(this.getUIContext(), '请填写至少一名学生的有效分数（0-100）');
      return;
    }
    this.submitting = true;
    TeacherRepository.get().submitGrades(this.courseId, scores).then((r: TeacherGradeResult) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), `已录入 ${r.updated} 人，进度 ${r.inputProgress}%`);
      this.reload();
    }).catch((e: object) => {
      this.submitting = false;
      Toast.show(this.getUIContext(), (e instanceof Error) ? (e as Error).message : '录入失败');
    });
  }

  // 已录入人数（原始已有成绩 + 本次填入合法分数）
  private enteredCount(): number {
    let n = 0;
    this.rows.forEach((r: EditRow) => {
      const text = r.input.trim();
      const valid = text.length > 0 && Number.isFinite(Number(text)) && Number(text) >= 0 && Number(text) <= 100;
      if (r.currentScore.length > 0 || valid) {
        n += 1;
      }
    });
    return n;
  }

  @Builder StudentRow(r: EditRow) {
    Row({ space: 10 }) {
      // 状态点：已有成绩=青绿，未评=浅灰
      Column()
        .width(8).height(8).borderRadius(4)
        .backgroundColor(r.currentScore.length > 0 ? '#5FB7A1' : ElysiaTheme.hairline())
      Column({ space: 2 }) {
        Text(r.name.length > 0 ? r.name : r.studentId)
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor(ElysiaTheme.INK)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(r.studentId).fontSize(11).fontColor(ElysiaTheme.INK_MUTE)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      if (r.currentScore.length > 0) {
        Pill({ text: `原 ${r.currentScore}` })
      }

      TextInput({ text: r.input, placeholder: '分数' })
        .type(InputType.Number)
        .width(72).height(40).textAlign(TextAlign.Center)
        .fontSize(14).fontColor(ElysiaTheme.INK)
        .backgroundColor(ElysiaTheme.glass())
        .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(12)
        .onChange((v: string) => this.updateInput(r.studentId, v))
    }
    .width('100%').padding(12).backgroundColor(ElysiaTheme.SURFACE)
    .border({ width: 1, color: ElysiaTheme.hairlineSoft() }).borderRadius(16)
  }

  build() {
    Stack() {
      RouteLoadingOverlay()
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: this.courseName, subtitle: this.className, onBack: () => AppRoute.back() })

        if (this.loading) {
          Column() { LoadingState({}) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else if (this.errorMsg.length > 0) {
          Column() { ErrorState({ message: this.errorMsg, onRetry: () => this.reload() }) }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Scroll() {
              Column({ space: 10 }) {
                if (this.distribution !== null) {
                  this.DistBar(this.distribution)
                }
                Row() {
                  Text(`学生名单（${this.rows.length}）`).fontSize(14).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK).layoutWeight(1)
                  Text(`已录入 ${this.enteredCount()}/${this.rows.length}`).fontSize(11).fontColor(ElysiaTheme.ROSE_500).fontWeight(FontWeight.Medium)
                }.width('100%').margin({ top: 4, bottom: 2 })
                Text('录入阶段 · 提交后由教务审核发布').fontSize(11).fontColor(ElysiaTheme.INK_MUTE).width('100%')

                if (this.rows.length === 0) {
                  EmptyState({ title: '该班暂无已注册学生' })
                } else {
                  ForEach(this.rows, (item: EditRow) => {
                    this.StudentRow(item)
                  }, (item: EditRow) => item.studentId)
                }
                SafeBottom()
              }.padding({ left: 16, right: 16, bottom: 16 })
            }.scrollBar(BarState.Off).layoutWeight(1)

            // 底部提交栏
            Row() {
              PrimaryButton({ text: this.submitting ? '提交中…' : '提交成绩', onTap: () => this.submit() })
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }.layoutWeight(1).width('100%')
        }
      }
      .width('100%').height('100%')
      .constraintSize({ maxWidth: BreakpointManager.contentMaxWidth(this.bp) })
    }.width('100%').height('100%')
  }
}

// 系统路由表构建函数
@Builder
export function TeacherCourseDetailPageBuilder() {
  NavDestination() {
    TeacherCourseDetailPage()
  }
  .hideTitleBar(true)
}
