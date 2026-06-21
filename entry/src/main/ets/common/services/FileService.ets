// 文件服务：头像选图与下载落点管理

import common from '@ohos.app.ability.common';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import image from '@ohos.multimedia.image';
import util from '@ohos.util';
import { LocalDataStore } from '../storage/LocalDataStore';
import { SessionStorage } from '../storage/SessionStorage';
import { AppConfig } from '../../app/AppConfig';
import { RemoteApi } from '../remote/RemoteApi';

const KEY_DOWNLOAD_HISTORY = 'local.downloadHistory.v1';
const MOCK_FILE_PREFIX = 'mock://files/';
const MOCK_DOWNLOAD_PREFIX = 'mock://downloads/';

export interface DownloadRecord {
  id: string;
  sourceUrl: string;
  fileName: string;
  savedPath: string;
  downloadedAt: string;
  isMock: boolean;
}

export class FileService {
  private static appContext?: common.Context;

  static configure(context: common.UIAbilityContext | common.Context): void {
    FileService.appContext = context;
  }

  // 按当前登录用户隔离持久化 key（学生优先，回退管理员），避免换账号串数据；均未登录时回退原 base。
  private static scopedKey(base: string): string {
    const session = SessionStorage.get();
    const student = session.getStudent();
    if (student && student.studentId.length > 0) {
      return `${base}.${student.studentId}`;
    }
    const admin = session.getAdmin();
    if (admin && admin.adminId.length > 0) {
      return `${base}.${admin.adminId}`;
    }
    return base;
  }

  // 清空当前用户的下载历史。缓存清理时调用：下载的附件已从 cacheDir 删除，
  // 历史记录指向的文件已不存在，故一并清空，保持一致。
  static async clearDownloadHistory(): Promise<void> {
    await LocalDataStore.saveArray<DownloadRecord>(FileService.scopedKey(KEY_DOWNLOAD_HISTORY), []);
  }

  // 选择头像并压缩为可持久化的 base64 data URL：
  // 相册 URI 仅本次进程有效、不可跨端，故选图后立即缩放至 256px + JPEG 80 压缩，
  // 编码为 data:image/jpeg;base64,... 存档（联机模式随资料落服务器，全端同步显示）。
  static async pickAvatarImage(): Promise<string> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;

    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select(options);
    const uri = result.photoUris.length > 0 ? result.photoUris[0] : '';
    if (uri.length === 0) {
      throw new Error('未选择图片');
    }
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      source = image.createImageSource(file.fd);
      const info = await source.getImageInfo();
      const maxSide = Math.max(info.size.width, info.size.height);
      const ratio = maxSide > 256 ? 256 / maxSide : 1;
      const decodeOpts: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(info.size.width * ratio)),
          height: Math.max(1, Math.round(info.size.height * ratio))
        }
      };
      pixelMap = await source.createPixelMap(decodeOpts);
      packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 80 };
      const buffer = await packer.packing(pixelMap, packOpts);
      const helper = new util.Base64Helper();
      const encoded = helper.encodeToStringSync(new Uint8Array(buffer));
      return `data:image/jpeg;base64,${encoded}`;
    } finally {
      if (packer) {
        packer.release();
      }
      if (pixelMap) {
        pixelMap.release();
      }
      if (source) {
        source.release();
      }
      fs.closeSync(file);
    }
  }

  // 选择头像并上传到对象存储（roadmap #9）：
  //   remote 模式：选图 → 压缩 base64 → POST /api/uploads → 返回 /api/uploads/<id> 服务端 URL。
  //   上传失败时优雅降级：回退返回本地 base64 data URL（避免因网络问题导致头像无法更新）。
  //   mock/local 模式：直接返回本地 base64 data URL（原有行为，不访问后端）。
  static async pickAndUploadAvatarImage(): Promise<string> {
    const dataUrl = await FileService.pickAvatarImage();
    if (!AppConfig.useRemote) {
      // mock / local 模式：直接返回 base64 data URL
      return dataUrl;
    }
    // remote 模式：尝试上传到对象存储
    try {
      // 剥离 data URL 前缀，提取 contentType 和纯 base64
      const match = dataUrl.match(/^data:([^;]+);base64,(.+)$/s);
      const contentType: string = match !== null ? match[1] : 'image/jpeg';
      const base64: string = match !== null ? match[2] : dataUrl;
      const result = await RemoteApi.uploadImage('avatar.jpg', contentType, base64);
      // 服务端返回相对路径（/api/uploads/up-xxxx）；ArkUI Image 控件无法解析相对路径，
      // 故用 baseUrl 的源（去掉尾部 /api）拼成绝对 https 地址，存库后各处渲染与下发后端均直接可用。
      const origin: string = AppConfig.baseUrl.replace(/\/api\/?$/, '');
      return origin + result.url;
    } catch (_e) {
      // 上传失败降级：返回本地 base64 data URL（后端 PUT /api/profile 仍可接受）
      return dataUrl;
    }
  }

  static async downloadFile(url: string, fileName: string): Promise<string> {
    const safeUrl = FileService.validateUrl(url);
    const safeFileName = FileService.validateFileName(fileName);

    if (safeUrl.startsWith(MOCK_FILE_PREFIX)) {
      return FileService.recordMockDownload(safeUrl, safeFileName);
    }

    if (safeUrl.startsWith('http://') || safeUrl.startsWith('https://')) {
      return FileService.downloadRemoteFile(safeUrl, safeFileName);
    }

    throw new Error('不支持的下载地址');
  }

  private static validateUrl(url: string): string {
    const value = (url ?? '').trim();
    if (value.length === 0) {
      throw new Error('下载地址不能为空');
    }
    if (FileService.hasControlCharacter(value)) {
      throw new Error('下载地址包含非法字符');
    }
    return value;
  }

  private static validateFileName(fileName: string): string {
    const value = (fileName ?? '').trim();
    if (value.length === 0) {
      throw new Error('文件名不能为空');
    }
    if (FileService.hasControlCharacter(value)) {
      throw new Error('文件名包含非法字符');
    }
    if (value.includes('..') || value.includes('/') || value.includes('\\')) {
      throw new Error('文件名不能包含路径');
    }
    return value;
  }

  private static hasControlCharacter(value: string): boolean {
    for (let i = 0; i < value.length; i += 1) {
      const code = value.charCodeAt(i);
      if (code < 32 || code === 127) {
        return true;
      }
    }
    return false;
  }

  private static async recordMockDownload(sourceUrl: string, fileName: string): Promise<string> {
    const savedPath = `${MOCK_DOWNLOAD_PREFIX}${encodeURIComponent(fileName)}`;
    const historyKey = FileService.scopedKey(KEY_DOWNLOAD_HISTORY);
    const history = await LocalDataStore.loadArray<DownloadRecord>(historyKey, []);
    const record: DownloadRecord = {
      id: `dl-${Date.now()}`,
      sourceUrl,
      fileName,
      savedPath,
      downloadedAt: new Date().toISOString(),
      isMock: true
    };
    const next = [record].concat(history);
    await LocalDataStore.saveArray<DownloadRecord>(historyKey, next);
    return savedPath;
  }

  private static async downloadRemoteFile(url: string, fileName: string): Promise<string> {
    const context = FileService.appContext;
    if (context === undefined) {
      throw new Error('文件服务未初始化');
    }
    const targetFolder = context.cacheDir.length > 0 ? context.cacheDir : context.filesDir;
    const session = rcp.createSession();
    const response = await session.downloadToFile(url, { kind: 'folder', path: targetFolder });
    const statusCode = response.statusCode;
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`下载失败（状态码 ${statusCode}）`);
    }
    const downloadedPath = response.downloadedTo?.path;
    if (downloadedPath === undefined || downloadedPath.length === 0) {
      throw new Error('下载未返回保存路径');
    }
    return downloadedPath;
  }

  // 鉴权导出到用户可见文件：
  // 1) 以 Bearer token 向后端发起 GET，下载到应用 cache；
  // 2) 用系统文件保存器（DocumentViewPicker.save）让用户选择目标位置，把 cache 字节复制过去；
  // 3) 用户取消保存器时静默返回空串（调用方据此不弹错或提示「已取消」）。
  // 返回最终用户保存路径；若系统保存器不可用，回退返回 cache 路径（调用方据此提示落点）。
  static async exportAuthedFile(path: string, suggestedName: string): Promise<string> {
    const safePath = (path ?? '').trim();
    if (safePath.length === 0) {
      throw new Error('导出地址不能为空');
    }
    if (FileService.hasControlCharacter(safePath)) {
      throw new Error('导出地址包含非法字符');
    }
    const safeName = FileService.validateFileName(suggestedName);

    const token = SessionStorage.get().getToken();
    if (token === undefined || token.length === 0) {
      throw new Error('未登录，无法导出');
    }

    const fullUrl = `${AppConfig.baseUrl}${safePath}`;
    const cachePath = await FileService.downloadAuthedToCache(fullUrl, safeName, token);
    return await FileService.saveCacheToUserFile(cachePath, safeName);
  }

  // 带 Authorization 头的下载到 cache：复用现有 downloadToFile 写法，仅在会话配置里追加请求头。
  private static async downloadAuthedToCache(url: string, fileName: string, token: string): Promise<string> {
    const context = FileService.appContext;
    if (context === undefined) {
      throw new Error('文件服务未初始化');
    }
    const targetFolder = context.cacheDir.length > 0 ? context.cacheDir : context.filesDir;
    const headers: Record<string, string> = { 'Authorization': `Bearer ${token}` };
    const sessionConfig: rcp.SessionConfiguration = { headers: headers };
    const session = rcp.createSession(sessionConfig);
    try {
      const response = await session.downloadToFile(url, { kind: 'folder', path: targetFolder });
      const statusCode = response.statusCode;
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`下载失败（状态码 ${statusCode}）`);
      }
      const downloadedPath = response.downloadedTo?.path;
      if (downloadedPath === undefined || downloadedPath.length === 0) {
        throw new Error('下载未返回保存路径');
      }
      return downloadedPath;
    } finally {
      session.close();
    }
  }

  // 把 cache 中的下载文件复制到用户通过系统保存器选择的目标 URI。
  // 用户取消 → 返回空串；保存器不可用 → 回退返回原 cache 路径。
  private static async saveCacheToUserFile(cachePath: string, fileName: string): Promise<string> {
    const context = FileService.appContext;
    if (context === undefined) {
      throw new Error('文件服务未初始化');
    }
    const destUri = await FileService.pickSaveDestination(context, fileName);
    if (destUri === undefined) {
      // 保存器不可用：保留 cache 路径供调用方提示
      return cachePath;
    }
    if (destUri.length === 0) {
      // 用户取消
      return '';
    }
    FileService.copyFile(cachePath, destUri);
    return destUri;
  }

  // 打开系统文件保存器选择目标位置。返回所选 URI；用户取消返回空串；
  // 当前 SDK 不支持 save 时返回 undefined（调用方据此回退到 cache 路径）。
  private static async pickSaveDestination(context: common.Context, fileName: string): Promise<string | undefined> {
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const uris: string[] = await documentPicker.save(options);
    if (uris.length === 0) {
      return '';
    }
    return uris[0];
  }

  // 同步复制：读取源文件全部字节，写入目标 URI（先 truncate 再写，避免残留旧内容）。
  private static copyFile(srcPath: string, destUri: string): void {
    const srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
    let destFile: fs.File | undefined = undefined;
    try {
      const stat = fs.statSync(srcFile.fd);
      const size = stat.size;
      destFile = fs.openSync(destUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      if (size <= 0) {
        return;
      }
      const buffer = new ArrayBuffer(size);
      const read = fs.readSync(srcFile.fd, buffer);
      fs.writeSync(destFile.fd, buffer, { length: read });
    } finally {
      if (destFile !== undefined) {
        fs.closeSync(destFile);
      }
      fs.closeSync(srcFile);
    }
  }
}
