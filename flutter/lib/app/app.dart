import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/domain/documents.dart';
import 'package:origin_mobile/data/chat/chat_store.dart';
import 'package:origin_mobile/features/assistant/assistant.dart';
import 'package:origin_mobile/features/messages/chat_info.dart';
import 'package:origin_mobile/features/messages/chat_page.dart';
import 'package:origin_mobile/features/messages/contact_picker.dart';
import 'package:origin_mobile/features/documents/document_list.dart';
import 'package:origin_mobile/features/documents/document_detail.dart';
import 'package:origin_mobile/features/auth/login.dart';
import 'package:origin_mobile/features/messages/messages.dart';
import 'package:origin_mobile/features/scan/scan.dart';
import 'package:origin_mobile/features/workspace/workspace.dart';
import 'package:origin_mobile/ui/brand.dart';
import 'package:origin_mobile/ui/common.dart';
import 'package:origin_mobile/ui/theme.dart';

class OriginApp extends StatelessWidget {
  final Session session;
  final ThemeData? theme;

  /// 测试可注入聊天状态（使用 Mock 或空实现），避免连接真实 WebSocket。
  final ChatStore Function(Session)? chatFactory;
  const OriginApp(this.session, {super.key, this.theme, this.chatFactory});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (_, _) => _RoutedApp(
      session,
      theme: theme,
      chatFactory: chatFactory,
      key: ValueKey('${session.api.generation}:${session.status.name}'),
    ),
  );
}

class _RoutedApp extends StatefulWidget {
  final Session session;
  final ThemeData? theme;
  final ChatStore Function(Session)? chatFactory;
  const _RoutedApp(this.session, {super.key, this.theme, this.chatFactory});
  @override
  State<_RoutedApp> createState() => _RoutedAppState();
}

class _RoutedAppState extends State<_RoutedApp> with WidgetsBindingObserver {
  late final GoRouter router;
  late final ChatStore chat =
      widget.chatFactory?.call(widget.session) ?? ChatStore(widget.session);
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
    WidgetsBinding.instance.addObserver(this);
    if (session.status == SessionStatus.authenticated &&
        session.businessAvailable) {
      unawaited(chat.bootstrap());
    }
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
        ].contains(state.uri.path)) {
          return '/workspace';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/startup', builder: (_, _) => const StartupScreen()),
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
          builder: (_, _, shell) => WorkspaceShell(shell, chat),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/messages',
                  builder: (_, _) => MessagesPage(session, chat),
                  routes: [
                    GoRoute(
                      path: 'system',
                      parentNavigatorKey: root,
                      builder: (_, _) => SystemNotificationsPage(session),
                    ),
                    GoRoute(
                      path: 'chat/:id',
                      parentNavigatorKey: root,
                      builder: (_, state) =>
                          ChatPage(chat, state.pathParameters['id']!),
                      routes: [
                        GoRoute(
                          path: 'info',
                          parentNavigatorKey: root,
                          builder: (_, state) =>
                              ChatInfoPage(chat, state.pathParameters['id']!),
                        ),
                        GoRoute(
                          path: 'add',
                          parentNavigatorKey: root,
                          builder: (_, state) => ContactPickerPage(
                            chat,
                            PickMode.add,
                            conversationId: state.pathParameters['id'],
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'contacts',
                      parentNavigatorKey: root,
                      builder: (_, _) => ContactsPage(chat),
                    ),
                    GoRoute(
                      path: 'new',
                      parentNavigatorKey: root,
                      builder: (_, state) => ContactPickerPage(
                        chat,
                        state.uri.queryParameters['mode'] == 'group'
                            ? PickMode.group
                            : PickMode.direct,
                        preselect: state.uri.queryParameters['with'],
                      ),
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) chat.resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    title: '原点智造',
    debugShowCheckedModeBanner: false,
    theme: widget.theme ?? AppTokens.theme,
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
  final ChatStore chat;
  const WorkspaceShell(this.shell, this.chat, {super.key});

  static const _items = [
    (Icons.chat_bubble_outline, Icons.chat_bubble, '消息'),
    (Icons.grid_view, Icons.grid_view_rounded, '工作台'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI助手'),
    (Icons.person_outline, Icons.person, '我的'),
  ];

  /// 「消息」标签显示员工聊天的未读数（静音会话不计入）。
  Widget _tabIcon(int index, IconData icon) => index == 0
      ? ListenableBuilder(
          listenable: chat,
          builder: (_, _) => Badge(
            isLabelVisible: chat.unreadTotal > 0,
            label: Text(chat.unreadTotal > 99 ? '99+' : '${chat.unreadTotal}'),
            child: Icon(icon),
          ),
        )
      : Icon(icon);

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
        for (var i = 0; i < _items.length; i++)
          NavigationDestination(
            icon: _tabIcon(i, _items[i].$1),
            selectedIcon: _tabIcon(i, _items[i].$2),
            label: _items[i].$3,
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
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 4),
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

/// 首屏：与原生启动画面同底色、同位置的标志，恢复登录态期间显示。
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTokens.brandDeep,
    body: Stack(
      children: [
        const Center(child: OriginLogo(size: 120, onDark: true)),
        // 标志位置与原生启动画面一致，文字与加载圈放在标志下方。
        Align(
          alignment: const Alignment(0, 0.42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '原点智造',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ORIGIN ERP',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.accent,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
