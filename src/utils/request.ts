import { appConfig } from "@/config/env";
import type { ApiResult, RequestOptions } from "@/types/api";
import { getToken, removeToken } from "@/utils/auth";

export class RequestError extends Error {
  readonly code?: number;
  readonly statusCode?: number;
  readonly data?: unknown;

  constructor(
    message: string,
    options: { code?: number; statusCode?: number; data?: unknown } = {},
  ) {
    super(message);
    this.name = "RequestError";
    this.code = options.code;
    this.statusCode = options.statusCode;
    this.data = options.data;
  }
}

const SUCCESS_CODE = 200;
const UNAUTHORIZED_CODE = 401;
let handlingUnauthorized = false;

function isAbsoluteUrl(url: string) {
  return /^https?:\/\//i.test(url);
}

function joinUrl(baseUrl: string, path: string) {
  if (isAbsoluteUrl(path)) return path;
  return `${baseUrl}/${path.replace(/^\/+/, "")}`;
}

function appendQuery(url: string, query?: Record<string, unknown>) {
  if (!query) return url;

  const values: string[] = [];
  Object.entries(query).forEach(([key, value]) => {
    if (value === undefined || value === null || value === "") return;
    const items = Array.isArray(value) ? value : [value];
    items.forEach((item) => {
      values.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(item))}`);
    });
  });

  if (!values.length) return url;
  return `${url}${url.includes("?") ? "&" : "?"}${values.join("&")}`;
}

function showError(message: string) {
  uni.showToast({
    title: message,
    icon: "none",
    duration: 2200,
  });
}

function handleUnauthorized() {
  removeToken();
  if (handlingUnauthorized) return;

  handlingUnauthorized = true;
  uni.reLaunch({
    url: "/pages/login/login",
    complete: () => {
      handlingUnauthorized = false;
    },
  });
}

function createNetworkError(error: UniApp.GeneralCallbackResult) {
  const rawMessage = error.errMsg || "";
  const message = /timeout/i.test(rawMessage)
    ? "请求超时，请检查网络后重试"
    : "网络连接失败，请稍后重试";
  return new RequestError(message);
}

export function request<T>(options: RequestOptions): Promise<T> {
  const {
    url,
    method = "GET",
    data,
    query,
    headers = {},
    timeout = appConfig.requestTimeout,
    auth = true,
    showError: shouldShowError = true,
  } = options;

  const token = auth ? getToken() : "";
  const header: Record<string, string> = {
    "Content-Type": "application/json",
    ...headers,
  };
  if (token) header.Authorization = `Bearer ${token}`;

  return new Promise((resolve, reject) => {
    uni.request({
      url: appendQuery(joinUrl(appConfig.apiBaseUrl, url), query),
      method,
      data: data as UniApp.RequestOptions["data"],
      header,
      timeout,
      success: (response: UniNamespace.RequestSuccessCallbackResult) => {
        const result = response.data as unknown as ApiResult<T>;
        const isUnauthorized =
          response.statusCode === UNAUTHORIZED_CODE || result?.code === UNAUTHORIZED_CODE;

        if (isUnauthorized) handleUnauthorized();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          const error = new RequestError(
            result?.msg || `请求失败（${response.statusCode}）`,
            { code: result?.code, statusCode: response.statusCode, data: result?.data },
          );
          if (shouldShowError && !isUnauthorized) showError(error.message);
          reject(error);
          return;
        }

        if (!result || typeof result.code !== "number") {
          const error = new RequestError("服务响应格式异常", {
            statusCode: response.statusCode,
            data: result,
          });
          if (shouldShowError) showError(error.message);
          reject(error);
          return;
        }

        if (result.code !== SUCCESS_CODE) {
          const error = new RequestError(result.msg || "请求失败", {
            code: result.code,
            statusCode: response.statusCode,
            data: result.data,
          });
          if (shouldShowError && !isUnauthorized) showError(error.message);
          reject(error);
          return;
        }

        resolve(result.data);
      },
      fail: (failure: UniNamespace.GeneralCallbackResult) => {
        const error = createNetworkError(failure);
        if (shouldShowError) showError(error.message);
        reject(error);
      },
    });
  });
}

export function get<T>(url: string, query?: Record<string, unknown>, options: Omit<RequestOptions, "url" | "method" | "query"> = {}) {
  return request<T>({ ...options, url, query, method: "GET" });
}

export function post<T>(url: string, data?: unknown, options: Omit<RequestOptions, "url" | "method" | "data"> = {}) {
  return request<T>({ ...options, url, data, method: "POST" });
}

export function put<T>(url: string, data?: unknown, options: Omit<RequestOptions, "url" | "method" | "data"> = {}) {
  return request<T>({ ...options, url, data, method: "PUT" });
}

export function del<T>(url: string, data?: unknown, options: Omit<RequestOptions, "url" | "method" | "data"> = {}) {
  return request<T>({ ...options, url, data, method: "DELETE" });
}
