// 文件服务：头像选图与下载落点管理

import common from '@ohos.app.ability.common';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import util from '@ohos.util';
import { LocalDataStore } from '../storage/LocalDataStore';
import { SessionStorage } from '../storage/SessionStorage';

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
}
