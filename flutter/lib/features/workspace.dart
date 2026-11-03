import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../domain/documents.dart';
import '../ui/cards.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

DocSpec specFor(String key) => documents.firstWhere((spec) => spec.key == key);
IconData appIcon(String key) => switch (key) {
  'scan' => Icons.qr_code_scanner,
  'inventory' => Icons.layers_outlined,
  'orders' => Icons.assignment_outlined,
  'reports' => Icons.edit_note,
  'picking' => Icons.output_outlined,
  'warehousing' => Icons.move_to_inbox_outlined,
  'receiving' => Icons.warehouse_outlined,
  _ => Icons.local_shipping_outlined,
};
Color appColor(String key) => switch (key) {
  'inventory' || 'picking' || 'warehousing' => const Color(0xFF2A8C6A),
  'receiving' => AppTokens.accent,
  'deliveries' => const Color(0xFF8B67C7),
  _ => AppTokens.brand,
};

class WorkspacePage extends StatefulWidget {
  final Session session;
  const WorkspacePage(this.session, {super.key});
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  List<({DocSpec spec, Json data})> tasks = [];
  List<Json> production = [];
  int total = 0, loadSequence = 0;
  bool loading = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ticket = ++loadSequence;
    setState(() {
      loading = true;
      error = null;
    });
    final next = <({DocSpec spec, Json data})>[];
    var nextTotal = 0;
    Object? failure;
    await Future.wait(
      ['warehousing', 'picking', 'receiving'].map((key) async {
        final spec = specFor(key);
        if (!widget.session.can(spec.permission)) return;
        try {
          final page = await DocumentRepository(
            widget.session,
          ).list(spec, {...spec.query(status: 1), 'pageSize': 3});
          nextTotal += asInt(page['total']);
          for (final row in (page['records'] as List).cast<Json>()) {
            next.add((spec: spec, data: row));
          }
        } catch (e) {
          failure = e;
        }
      }),
    );
    List<Json> active = [];
    if (widget.session.can(specFor('orders').permission)) {
      try {
        final page = await DocumentRepository(widget.session).list(
          specFor('orders'),
          {...specFor('orders').query(status: 2), 'pageSize': 2},
        );
        active = (page['records'] as List).cast<Json>();
      } catch (e) {
        failure = e;
      }
    }
    if (mounted && ticket == loadSequence)
      setState(() {
        tasks = next
          ..sort(
            (a, b) => ['warehousing', 'picking', 'receiving']
                .indexOf(a.spec.key)
                .compareTo(
                  ['warehousing', 'picking', 'receiving'].indexOf(b.spec.key),
                ),
          );
        production = active;
        total = nextTotal;
        error = failure;
        loading = false;
      });
  }

  void open(DocSpec spec, {int? status}) => context.push(
    '/workspace/${spec.key}${status == null ? '' : '?status=$status'}',
  );
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: organizationBar(context, widget.session),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          children: [
            _WorkspaceHero(
              date:
                  '${now.year}年${now.month}月${now.day}日 周${'一二三四五六日'[now.weekday - 1]}',
              stats: [
                (label: '待处理业务', value: loading ? '—' : '$total'),
                (
                  label: '进行中的生产',
                  value: loading ? '—' : '${production.length}',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                readOnly: true,
                onTap: () => context.push('/workspace/apps'),
                decoration: InputDecoration(
                  hintText: '搜索应用',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            GroupCard(
              child: Column(
                children: [
                  SectionHeading(
                    '常用应用',
                    action: '全部',
                    onPressed: () => context.push('/workspace/apps'),
                  ),
                  ApplicationGrid(
                    widget.session,
                    keys: const [
                      'scan',
                      'inventory',
                      'orders',
                      'reports',
                      'picking',
                      'warehousing',
                      'receiving',
                      'deliveries',
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SectionGap(),
            GroupCard(
              child: Column(
                children: [
                  SectionHeading(
                    '待处理业务',
                    count: loading ? null : total,
                    action: '查看全部',
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (c) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '组织待处理单据',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text('按当前账号权限展示；当前接口尚未提供个人任务分配。'),
                              for (final key in [
                                'warehousing',
                                'picking',
                                'receiving',
                              ])
                                if (widget.session.can(specFor(key).permission))
                                  ListTile(
                                    title: Text(specFor(key).title),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.pop(c);
                                      open(specFor(key), status: 1);
                                    },
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null) StateNotice('部分作业加载失败，请重试', retry: load),
                  if (!loading && tasks.isEmpty && error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: StateNotice('暂无待处理单据'),
                    ),
                  for (final task in tasks.take(3))
                    TaskRow(
                      task.spec,
                      task.data,
                      onTap: () => context.push(
                        '/workspace/${task.spec.key}/${task.data['id']}',
                      ),
                    ),
                ],
              ),
            ),
            if (production.isNotEmpty) ...[
              const SectionGap(),
              GroupCard(
                child: Column(
                  children: [
                    SectionHeading(
                      '进行中的生产',
                      action: '全部',
                      onPressed: () => open(specFor('orders'), status: 2),
                    ),
                    for (final order in production)
                      TaskRow(
                        last: order == production.last,
                        specFor('orders'),
                        order,
                        onTap: () =>
                            context.push('/workspace/orders/${order['id']}'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  final String date;
  final List<({String label, String value})> stats;
  const _WorkspaceHero({required this.date, required this.stats});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppTokens.radius + 4),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTokens.brandDeep, AppTokens.brand],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ORIGIN ERP / 业务工作台',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: AppTokens.accent,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '今日业务概览',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final stat in stats)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: stat == stats.last ? 0 : 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        stat.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class ApplicationGrid extends StatelessWidget {
  final Session session;
  final List<String> keys;
  const ApplicationGrid(this.session, {super.key, required this.keys});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth < 300 ? 3 : 4;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(
          runSpacing: 8,
          children: [
            for (final key in keys)
              if (session.can(
                specFor(key == 'scan' ? 'inventory' : key).permission,
              ))
                SizedBox(
                  width: (size.maxWidth - 16) / columns,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      if (key == 'scan') {
                        final code = await context.push<String>('/scan');
                        if (code != null && context.mounted)
                          context.push(
                            '/workspace/inventory?keyword=${Uri.encodeQueryComponent(code)}',
                          );
                      } else {
                        context.push('/workspace/$key');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 3,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: appColor(key).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              appIcon(key),
                              color: appColor(key),
                              size: 23,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            key == 'scan' ? '扫一扫' : specFor(key).title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class TaskRow extends StatelessWidget {
  final DocSpec spec;
  final Json data;
  final VoidCallback onTap;
  final bool last;
  const TaskRow(
    this.spec,
    this.data, {
    super.key,
    required this.onTap,
    this.last = false,
  });
  @override
  Widget build(BuildContext context) {
    final color = appColor(spec.key);
    final labels = {
      'warehousing': '成品入库待确认',
      'picking': '生产领料待处理',
      'receiving': '采购到货待上架',
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(bottom: BorderSide(color: AppTokens.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(appIcon(spec.key), size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              labels[spec.key] ??
                                  '${data['materialName'] ?? spec.title}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusTag(
                            spec.statusLabel(data['status']),
                            color: color,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${data[spec.number] ?? ''} · ${spec.key == 'orders' ? '已完成 ${fmtNum(data['completedQuantity'])} / ${fmtNum(data['plannedQuantity'])}' : data['materialName'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTokens.muted,
                        ),
                      ),
                      if (data['warehouseName'] != null)
                        Text(
                          '${data['warehouseName']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTokens.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppTokens.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppsPage extends StatefulWidget {
  final Session session;
  const AppsPage(this.session, {super.key});
  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  String keyword = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: OrgTitle(widget.session, '全部应用'),
      toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
    ),
    body: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索应用名称',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => keyword = v.trim()),
          ),
        ),
        for (final group in [
          ('仓储作业', ['scan', 'inventory', 'picking', 'warehousing']),
          ('生产执行', ['orders', 'reports']),
          ('采购与销售', ['receiving', 'deliveries', 'sales']),
        ]) ...[
          SectionHeading(group.$1),
          GroupCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ApplicationGrid(
                widget.session,
                keys: group.$2
                    .where(
                      (key) => (key == 'scan' ? '扫一扫' : specFor(key).title)
                          .contains(keyword),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class ProfilePage extends StatelessWidget {
  final Session session;
  const ProfilePage(this.session, {super.key});

  Widget row(
    IconData icon,
    String title, {
    String? value,
    VoidCallback? onTap,
  }) => ListTile(
    leading: Icon(icon, size: 20, color: AppTokens.muted),
    title: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
          ),
        if (onTap != null)
          const Icon(Icons.chevron_right, size: 18, color: AppTokens.muted),
      ],
    ),
    onTap: onTap,
  );

  Widget card(List<Widget> children) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 20, endIndent: 20),
            children[i],
          ],
        ],
      ),
    ),
  );

  Future<void> switchOrganization(BuildContext context) async {
    if (await confirm(context, '切换组织', '将退出当前账号并重新登录，未提交内容将丢失。')) {
      await session.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = session.name;
    final roles = ((session.profile['roles'] as List?) ?? [])
        .map((r) => r['roleName'])
        .join(' / ');
    return Scaffold(
      appBar: organizationBar(context, session),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTokens.brandSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isEmpty ? '' : name.substring(0, 1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5A6B8C),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        roles,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          card([
            row(
              Icons.apartment_outlined,
              '所属组织',
              value: '${session.organization['name'] ?? ''}',
              onTap: () => switchOrganization(context),
            ),
            row(
              Icons.person_outline,
              '账号',
              value: '${session.profile['username'] ?? ''}',
            ),
            row(Icons.verified_user_outlined, '角色与权限', value: roles),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.white,
                foregroundColor: AppTokens.muted,
                side: const BorderSide(color: AppTokens.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                ),
              ),
              onPressed: () async {
                if (await confirm(context, '退出登录', '未提交内容将丢失，确认退出？')) {
                  await session.logout();
                }
              },
              child: const Text('退出登录'),
            ),
          ),
          if (session.error != null)
            StateNotice(session.error!, retry: session.logout),
        ],
      ),
    );
  }
}
