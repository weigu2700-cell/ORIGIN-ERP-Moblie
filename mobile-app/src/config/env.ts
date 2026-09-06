// 后续 request 封装统一从这里读取地址；原生端不能使用 H5 的相对代理路径。
let apiBaseUrl = import.meta.env.VITE_API_BASE_URL || "/api";
// #ifndef H5
apiBaseUrl = import.meta.env.VITE_NATIVE_API_BASE_URL || "";
// #endif

export const appConfig = Object.freeze({
  name: "原点智造 ERP",
  apiBaseUrl: apiBaseUrl.replace(/\/+$/, ""),
  requestTimeout: 15000,
});
