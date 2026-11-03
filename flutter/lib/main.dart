import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'domain/documents.dart';
import 'features/assistant.dart';
import 'features/document_list.dart';
import 'features/document_detail.dart';
import 'features/login.dart';
import 'features/messages.dart';
import 'features/scan.dart';
import 'features/workspace.dart';
import 'ui/common.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  final session = Session(
    ApiClient(baseUrl),
    SecureTokenVault(key: 'origin.token.${Uri.encodeComponent(baseUrl)}'),
  );
  runApp(OriginApp(session));
  session.restore();
}

class OriginApp extends StatelessWidget {
  final Session session;
  const OriginApp(this.session, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (_, _) => _RoutedApp(
      session,
      key: ValueKey('${session.api.generation}:${session.status.name}'),
    ),
  );
}

class _RoutedApp extends StatefulWidget {
  final Session session;
  const _RoutedApp(this.session, {super.key});
  @override
  State<_RoutedApp> createState() => _RoutedAppState();
}

class _RoutedAppState extends State<_RoutedApp> {
  late final GoRouter router;
  final root = GlobalKey<NavigatorState>();
  Session get session => widget.session;
  String get landing => switch (session.status) {
    SessionStatus.restoring => '/startup',
    SessionStatus.anonymous => '/login',
    SessionStatus.error => '/session-error',
    SessionStatus.authenticated =>
      session.businessAvailable ? '/workspace' : '/organization-unavailable',
  };
  @override
  void initState() {
    super.initState();
    router = GoRouter(
      navigatorKey: root,
      initialLocation: landing,
      refreshListenable: session,
      redirect: (_, state) {
        final restricted =
            session.status != SessionStatus.authenticated ||
            !session.businessAvailable;
        if (restricted) return state.uri.path == landing ? null : landing;
        if ([
          '/startup',
          '/login',
          '/session-error',
          '/organization-unavailable',
        ].contains(state.uri.path))
          return '/workspace';
        return null;
      },
      routes: [
        GoRoute(
          path: '/startup',
          builder: (_, _) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(path: '/login', builder: (_, _) => LoginPage(session)),
        GoRoute(
          path: '/session-error',
          builder: (_, _) => Scaffold(
            body: StateNotice(
              session.error ?? '身份验证失败',
              retry: session.restore,
            ),
            bottomNavigationBar: SafeArea(
              child: TextButton(
                onPressed: session.logout,
                child: const Text('退出并重新登录'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/organization-unavailable',
          builder: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('组织业务尚未开放')),
            body: const StateNotice('当前组织可登录，业务功能尚未开放。请联系管理员或切换组织。'),
            bottomNavigationBar: SafeArea(
              child: TextButton(
                onPressed: session.logout,
                child: const Text('退出并切换组织'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/scan',
          builder: (_, state) =>
              ScanPage(expected: state.uri.queryParameters['expected']),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => WorkspaceShell(shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/messages',
                  builder: (_, _) => MessagesPage(session),
                  routes: [
                    GoRoute(
                      path: 'system',
                      parentNavigatorKey: root,
                      builder: (_, _) => SystemNotificationsPage(session),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/workspace',
                  builder: (_, _) => WorkspacePage(session),
                  routes: [
                    GoRoute(
                      path: 'apps',
                      parentNavigatorKey: root,
                      builder: (_, _) => AppsPage(session),
                    ),
                    for (final spec in documents)
                      GoRoute(
                        path: spec.key,
                        parentNavigatorKey: root,
                        builder: (_, state) => DocumentListPage(
                          session,
                          spec,
                          initialKeyword: state.uri.queryParameters['keyword'],
                          initialStatus: int.tryParse(
                            state.uri.queryParameters['status'] ?? '',
                          ),
                          orderId: state.uri.queryParameters['orderId'],
                        ),
                        routes: [
                          GoRoute(
                            path: ':id',
                            parentNavigatorKey: root,
                            builder: (_, state) => DocumentDetailPage(
                              session,
                              spec,
                              state.pathParameters['id']!,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/assistant',
                  builder: (_, _) => AssistantPage(session),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/me', builder: (_, _) => ProfilePage(session)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    title: '原点智造',
    debugShowCheckedModeBanner: false,
    theme: AppTokens.theme,
    // 横屏时避开灵动岛/刘海的左右安全区；上下由 AppBar、底栏各自处理。
    builder: (context, child) =>
        SafeArea(top: false, bottom: false, child: child!),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  );
}

class WorkspaceShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const WorkspaceShell(this.shell, {super.key});

  static const _items = [
    (Icons.chat_bubble_outline, Icons.chat_bubble, '消息'),
    (Icons.grid_view, Icons.grid_view_rounded, '工作台'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI助手'),
    (Icons.person_outline, Icons.person, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final bar = NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      backgroundColor: ios ? Colors.transparent : null,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: Icon(item.$1),
            selectedIcon: Icon(item.$2),
            label: item.$3,
          ),
      ],
    );
    if (!ios) return Scaffold(body: shell, bottomNavigationBar: bar);
    // iOS：悬浮毛玻璃标签栏，内容可滚动到栏下方；SafeArea 避开 Home 指示条与横屏刘海。
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                  ),
                  child: bar,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
