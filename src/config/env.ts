// 原生端不能使用 H5 的相对代理路径。
let apiBaseUrl = import.meta.env.VITE_API_BASE_URL || '/api';
let requiresAbsoluteApiBaseUrl = false;
// #ifndef H5
apiBaseUrl = import.meta.env.VITE_NATIVE_API_BASE_URL || '';
requiresAbsoluteApiBaseUrl = true;
// #endif

apiBaseUrl = apiBaseUrl.replace(/\/+$/, '');
const apiBaseUrlConfigured = !requiresAbsoluteApiBaseUrl || /^https?:\/\//i.test(apiBaseUrl);

export const appConfig = Object.freeze({
  name: '原点智造 ERP',
  apiBaseUrl,
  apiBaseUrlConfigured,
  apiBaseUrlError: apiBaseUrlConfigured
    ? ''
    : '原生端 API 地址未配置，请设置 VITE_NATIVE_API_BASE_URL（需为 http(s) 绝对地址）',
  requestTimeout: 15000,
});
