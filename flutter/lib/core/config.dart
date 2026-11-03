/// 编译期配置，通过 `--dart-define` 或 `--dart-define-from-file` 注入。
class AppConfig {
  /// 后端地址（绝对地址，不带 `/api` 前缀）。未配置时登录页会提示。
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// 令牌按服务器地址隔离存储，切换环境不会串用登录态。
  static String get tokenKey =>
      'origin.token.${Uri.encodeComponent(apiBaseUrl)}';
}
