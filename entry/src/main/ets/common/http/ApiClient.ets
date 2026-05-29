// 全局 API 客户端 · 启动时接入会话 token 与 401 处理

import { AppConfig } from '../../app/AppConfig';
import { HttpClient } from './HttpClient';

export const apiClient = new HttpClient(AppConfig.baseUrl);
