// LazyForEach 通用数据源：包装数组实现 IDataSource，让长列表按需创建节点（虚拟化）。
// 用法：
//   private ds: ArrayDataSource<Course> = new ArrayDataSource();
//   this.ds.setData(list);                          // 数据就绪后灌入
//   List() { LazyForEach(this.ds, (item: Course) => { ListItem() { ... } }, (item: Course) => item.id) }
//     .cachedCount(4)
export class ArrayDataSource<T> implements IDataSource {
  private items: T[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(items?: T[]) {
    if (items) {
      this.items = items;
    }
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): T {
    return this.items[index];
  }

  // 整表替换并通知刷新（页面每次加载完成调用）。
  setData(items: T[]): void {
    this.items = items;
    this.listeners.forEach((l: DataChangeListener) => {
      l.onDataReloaded();
    });
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }
}
