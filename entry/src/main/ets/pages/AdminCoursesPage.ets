// 课程管理 · Cours
import { ElysiaTheme } from '../common/Theme';
import { TopBar, Pill, PrimaryButton, GhostButton, ElysiaInput } from '../common/Components';
import { AdminTabBar } from '../common/widgets/TabBars';
import { AdminRepository } from '../repositories/AdminRepository';
import { AdminCourseItem, AdminCourseWritePayload, AdminCourseCategory, AdminCourseStatus } from '../models/Admin';
import { AppRoute, Routes } from '../app/AppRoute';
import { LoadingState, EmptyState, ErrorState } from '../common/widgets/StateViews';
import { HttpError } from '../common/http/HttpError';
import promptAction from '@ohos.promptAction';
import { SafeTop } from '../common/widgets/SafeArea';

@Entry
@Component
struct AdminCoursesPage {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMsg: string = '';
  @State formError: string = '';
  @State query: string = '';
  @State courses: AdminCourseItem[] = [];
  @State activeCategory: string = '全部';
  @State isEditing: boolean = false;
  @State editingId: string = '';
  @State code: string = '';
  @State name: string = '';
  @State teacher: string = '';
  @State category: string = 'required';
  @State creditText: string = '2';
  @State timeText: string = '';
  @State capacityText: string = '60';
  @State selectedCountText: string = '0';
  @State status: string = 'draft';
  @State pendingDeleteId: string = '';
  private categories: string[] = ['全部', 'required', 'elective', 'public', 'practice'];
  private catLabels: string[] = ['全部', '必修', '选修', '公选', '实践'];
  private editCategories: string[] = ['required', 'elective', 'public', 'practice'];
  private editCatLabels: string[] = ['必修', '选修', '公选', '实践'];
  private statuses: string[] = ['draft', 'open', 'closed', 'archived'];
  private statusLabels: string[] = ['草稿', '开课中', '已关闭', '归档'];

  aboutToAppear(): void {
    if (!AppRoute.guard(Routes.AdminCourses)) {
      return;
    }
    this.loadData();
  }

  private loadData(): void {
    this.loading = true;
    this.errorMsg = '';
    const cat = this.activeCategory === '全部' ? undefined : this.activeCategory;
    AdminRepository.get().getCourses(this.query, cat).then((list: AdminCourseItem[]) => {
      this.courses = list;
      this.loading = false;
    }).catch((e: object) => {
      this.errorMsg = e instanceof Error ? e.message : '加载失败';
      this.loading = false;
    });
  }

  private statusLabel(s: string): string {
    if (s === 'open') return '开课中';
    if (s === 'closed') return '已关闭';
    if (s === 'draft') return '草稿';
    return '归档';
  }

  private statusColor(s: string): string {
    if (s === 'open') return '#7BB07B';
    if (s === 'closed') return '#D8546B';
    if (s === 'draft') return '#D9B675';
    return ElysiaTheme.INK_MUTE;
  }

  private resetForm(): void {
    this.editingId = '';
    this.code = '';
    this.name = '';
    this.teacher = '';
    this.category = 'required';
    this.creditText = '2';
    this.timeText = '';
    this.capacityText = '60';
    this.selectedCountText = '0';
    this.status = 'draft';
    this.formError = '';
  }

  private openCreate(): void {
    this.pendingDeleteId = '';
    this.resetForm();
    this.isEditing = true;
  }

  private openEdit(c: AdminCourseItem): void {
    this.pendingDeleteId = '';
    this.editingId = c.id;
    this.code = c.code;
    this.name = c.name;
    this.teacher = c.teacher;
    this.category = c.category;
    this.creditText = `${c.credit}`;
    this.timeText = c.timeText;
    this.capacityText = `${c.capacity}`;
    this.selectedCountText = `${c.selectedCount}`;
    this.status = c.status;
    this.formError = '';
    this.isEditing = true;
  }

  private cancelEdit(): void {
    this.isEditing = false;
    this.resetForm();
  }

  private toPositiveNumber(value: string): number {
    const parsed = Number(value.trim());
    if (parsed !== parsed || parsed === Infinity || parsed === -Infinity) {
      return -1;
    }
    return parsed;
  }

  private buildPayload(): AdminCourseWritePayload | null {
    const credit = this.toPositiveNumber(this.creditText);
    const capacity = this.toPositiveNumber(this.capacityText);
    const selectedCount = this.toPositiveNumber(this.selectedCountText);
    if (credit <= 0) {
      this.formError = '学分必须大于 0';
      return null;
    }
    if (capacity <= 0 || Math.floor(capacity) !== capacity) {
      this.formError = '容量必须为正整数';
      return null;
    }
    if (selectedCount < 0 || Math.floor(selectedCount) !== selectedCount) {
      this.formError = '已选人数必须为非负整数';
      return null;
    }
    if (selectedCount > capacity) {
      this.formError = '已选人数不能大于容量';
      return null;
    }
    return {
      code: this.code,
      name: this.name,
      teacher: this.teacher,
      category: this.category as AdminCourseCategory,
      credit: credit,
      timeText: this.timeText,
      capacity: capacity,
      selectedCount: selectedCount,
      status: this.status as AdminCourseStatus
    };
  }

  private saveCourse(): void {
    if (this.submitting) return;
    const payload = this.buildPayload();
    if (payload === null) return;
    this.submitting = true;
    this.formError = '';
    const repo = AdminRepository.get();
    const action = this.editingId.length > 0 ? repo.updateCourse(this.editingId, payload) : repo.createCourse(payload);
    action.then(() => {
      this.submitting = false;
      promptAction.showToast({ message: this.editingId.length > 0 ? '课程已更新' : '课程已新增' });
      this.cancelEdit();
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      this.formError = (e instanceof HttpError) ? (e as HttpError).message : '保存失败';
    });
  }

  private requestDelete(c: AdminCourseItem): void {
    if (this.submitting) return;
    this.pendingDeleteId = c.id;
    this.formError = `确认删除课程「${c.name}」？`;
  }

  private cancelDelete(): void {
    this.pendingDeleteId = '';
    this.formError = '';
  }

  private deleteCourse(c: AdminCourseItem): void {
    if (this.submitting) return;
    this.submitting = true;
    this.formError = '';
    AdminRepository.get().deleteCourse(c.id).then(() => {
      this.submitting = false;
      this.pendingDeleteId = '';
      promptAction.showToast({ message: '课程已删除' });
      if (this.editingId === c.id) {
        this.cancelEdit();
      }
      this.loadData();
    }).catch((e: object) => {
      this.submitting = false;
      const msg = (e instanceof HttpError) ? (e as HttpError).message : '删除失败';
      this.formError = msg;
      promptAction.showToast({ message: msg });
    });
  }

  build() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: ElysiaTheme.pageGradient() })

      Column() {
        SafeTop()
        TopBar({ title: 'Cours', subtitle: '课 程 管 理', showBack: false })

        Column({ space: 10 }) {
          Row({ space: 10 }) {
            TextInput({ placeholder: '搜索课程/课号/教师', text: this.query })
              .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
              .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
              .layoutWeight(1)
              .onChange((v: string) => { this.query = v; this.loadData(); })
            Text('新增').fontSize(13).fontColor(Color.White).fontWeight(FontWeight.Bold)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(ElysiaTheme.ROSE_500).borderRadius(999)
              .onClick(() => { this.openCreate(); })
          }.width('100%')

          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.catLabels, (label: string, idx: number) => {
                Text(label).fontSize(11)
                  .fontColor(this.activeCategory === this.categories[idx] ? Color.White : ElysiaTheme.ROSE_700)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor(this.activeCategory === this.categories[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                  .borderRadius(999)
                  .onClick(() => { this.activeCategory = this.categories[idx]; this.loadData(); })
              }, (label: string, idx: number) => this.categories[idx])
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        }.padding({ left: 16, right: 16 })

        if (this.isEditing) {
          Scroll() {
            Column({ space: 10 }) {
              Text(this.editingId.length > 0 ? '编辑课程' : '新增课程')
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ElysiaTheme.INK)
              ElysiaInput({ placeholder: '课程代码', value: $code, leadingIcon: 'edit' })
              ElysiaInput({ placeholder: '课程名称', value: $name, leadingIcon: 'course' })
              ElysiaInput({ placeholder: '教师', value: $teacher, leadingIcon: 'teacher' })
              ElysiaInput({ placeholder: '上课时间，如：周一 1-2 节', value: $timeText, leadingIcon: 'time' })
              Row({ space: 8 }) {
                TextInput({ placeholder: '学分', text: this.creditText })
                  .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
                  .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                  .layoutWeight(1)
                  .onChange((v: string) => { this.creditText = v; })
                TextInput({ placeholder: '容量', text: this.capacityText })
                  .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
                  .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                  .layoutWeight(1)
                  .onChange((v: string) => { this.capacityText = v; })
                TextInput({ placeholder: '已选', text: this.selectedCountText })
                  .height(40).fontSize(13).backgroundColor(ElysiaTheme.glass())
                  .border({ width: 1, color: ElysiaTheme.hairline() }).borderRadius(14)
                  .layoutWeight(1)
                  .onChange((v: string) => { this.selectedCountText = v; })
              }.width('100%')

              Column({ space: 6 }) {
                Text('课程类型').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                Row({ space: 8 }) {
                  ForEach(this.editCatLabels, (label: string, idx: number) => {
                    Text(label).fontSize(12)
                      .fontColor(this.category === this.editCategories[idx] ? Color.White : ElysiaTheme.ROSE_700)
                      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                      .backgroundColor(this.category === this.editCategories[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                      .borderRadius(999)
                      .onClick(() => { this.category = this.editCategories[idx]; })
                  }, (label: string, idx: number) => `cat-${idx}`)
                }
              }.width('100%').alignItems(HorizontalAlign.Start)

              Column({ space: 6 }) {
                Text('课程状态').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                Row({ space: 8 }) {
                  ForEach(this.statusLabels, (label: string, idx: number) => {
                    Text(label).fontSize(12)
                      .fontColor(this.status === this.statuses[idx] ? Color.White : ElysiaTheme.ROSE_700)
                      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                      .backgroundColor(this.status === this.statuses[idx] ? ElysiaTheme.ROSE_500 : '#FFE9F1')
                      .borderRadius(999)
                      .onClick(() => { this.status = this.statuses[idx]; })
                  }, (label: string, idx: number) => `status-${idx}`)
                }
              }.width('100%').alignItems(HorizontalAlign.Start)

              if (this.formError.length > 0) {
                Text(this.formError).fontSize(12).fontColor('#D8546B')
              }

              Row({ space: 10 }) {
                GhostButton({ text: '取消', onTap: () => this.cancelEdit() }).layoutWeight(1)
                PrimaryButton({ text: this.submitting ? '保存中...' : '保存课程', onTap: () => this.saveCourse() }).layoutWeight(1)
              }
            }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(18)
            .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
          }.height(430).padding({ left: 16, right: 16, top: 10 }).scrollBar(BarState.Off)
        } else if (this.formError.length > 0) {
          Text(this.formError).fontSize(12).fontColor('#D8546B')
            .padding({ left: 16, right: 16, top: 8 })
        }

        if (this.loading) {
          LoadingState({})
        } else if (this.errorMsg.length > 0) {
          ErrorState({ message: this.errorMsg, onRetry: () => this.loadData() })
        } else if (this.courses.length === 0) {
          EmptyState({ title: '无匹配课程' })
        } else {
          List() {
            ForEach(this.courses, (c: AdminCourseItem) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(c.name).fontSize(14).fontColor(ElysiaTheme.INK).layoutWeight(1)
                    Pill({ text: this.statusLabel(c.status), color: this.statusColor(c.status), bg: ElysiaTheme.SURFACE_GLOW })
                  }.width('100%')
                  Text(`${c.code} · ${c.teacher} · ${c.credit} 学分 · ${c.timeText}`).fontSize(11).fontColor(ElysiaTheme.INK_SOFT)
                  Row() {
                    Column().height(6).width(`${Math.min(c.selectedCount / c.capacity * 100, 100)}%`)
                      .backgroundColor(c.selectedCount >= c.capacity ? '#D8546B' : ElysiaTheme.ROSE_500).borderRadius(3)
                  }.width('100%').height(6).backgroundColor('#FFE9F1').borderRadius(3)
                  Row() {
                    if (this.pendingDeleteId === c.id) {
                      Text(`确认删除「${c.name}」`).fontSize(11).fontColor('#D8546B').layoutWeight(1)
                      Text('取消').fontSize(12).fontColor(ElysiaTheme.INK_MUTE)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor('#F5F2F4').borderRadius(999)
                        .margin({ right: 10 })
                        .onClick(() => { this.cancelDelete(); })
                      Text('确认删除').fontSize(12).fontColor(Color.White)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor('#D8546B').borderRadius(999)
                        .onClick(() => { this.deleteCourse(c); })
                    } else {
                      Text(`${c.selectedCount}/${c.capacity}`).fontSize(10).fontColor(ElysiaTheme.INK_MUTE).layoutWeight(1)
                      Text('编辑').fontSize(12).fontColor(ElysiaTheme.ROSE_700)
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor('#FFE9F1').borderRadius(999)
                        .margin({ right: 12 })
                        .onClick(() => { this.openEdit(c); })
                      Text('删除').fontSize(12).fontColor('#D8546B')
                        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                        .backgroundColor('#FFF0F3').borderRadius(999)
                        .onClick(() => { this.requestDelete(c); })
                    }
                  }.width('100%').alignItems(VerticalAlign.Center)
                }.width('100%').padding(14).backgroundColor(ElysiaTheme.SURFACE).borderRadius(14)
                .border({ width: 1, color: ElysiaTheme.hairlineSoft() })
              }.margin({ bottom: 8 })
            }, (c: AdminCourseItem) => c.id)
          }.layoutWeight(1).padding({ left: 16, right: 16, top: 10 })
        }

        AdminTabBar({ active: 'courses', onTap: (id: string, route: string) => { AppRoute.go(route, { replace: true }); } })
      }
    }.width('100%').height('100%')
  }
}
