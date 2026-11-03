import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../domain/warehouses.dart';
import '../domain/documents.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../ui/cards.dart';

class DocumentListPage extends StatefulWidget {
  final Session session;
  final DocSpec spec;
  final String? orderId;
  final String? initialKeyword;
  final int? initialStatus;
  const DocumentListPage(
    this.session,
    this.spec, {
    super.key,
    this.orderId,
    this.initialKeyword,
    this.initialStatus,
  });
  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  final search = TextEditingController();
  List<Json> rows = [], warehouses = [];
  String? warehouseId, error;
  int? status;
  int page = 1, total = 0, sequence = 0;
  bool loading = true, more = false;
  @override
  void initState() {
    super.initState();
    search.text = widget.initialKeyword ?? '';
    status = widget.initialStatus;
    load();
    loadWarehouses();
  }

  Future<void> loadWarehouses() async {
    if (!widget.spec.warehouse ||
        !widget.session.can('master:warehouse:list')) {
      return;
    }
    try {
      final enabled = await WarehouseRepository(widget.session).enabled();
      if (mounted) setState(() => warehouses = enabled);
    } catch (_) {
      /* 主列表可独立使用。 */
    }
  }

  Future<void> load({bool append = false}) async {
    if (append && (more || loading)) return;
    final ticket = ++sequence;
    final next = append ? page + 1 : 1;
    setState(() {
      if (append) {
        more = true;
      } else {
        loading = true;
      }
      error = null;
    });
    try {
      final data = await DocumentRepository(widget.session).list(
        widget.spec,
        widget.spec.query(
          page: next,
          keyword: search.text.trim(),
          status: status,
          warehouseId: warehouseId,
          orderId: widget.orderId,
        ),
      );
      if (!mounted || ticket != sequence) return;
      setState(() {
        final items = (data['records'] as List).cast<Json>();
        rows = append ? [...rows, ...items] : items;
        page = next;
        total = asInt(data['total']);
      });
    } catch (e) {
      if (mounted && ticket == sequence) setState(() => error = e.toString());
    } finally {
      if (mounted && ticket == sequence) {
        setState(() {
          loading = false;
          more = false;
        });
      }
    }
  }

  @override
  void dispose() {
    sequence++;
    search.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    final value = await context.push<String>('/scan');
    if (value != null && mounted) {
      search.text = value;
      load();
    }
  }

  Future<void> chooseWarehouse() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '选择仓库',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final w in [
              {'id': '', 'name': '全部仓库'},
              ...warehouses,
            ])
              ListTile(
                title: Text('${w['name']}'),
                trailing: (warehouseId ?? '') == '${w['id']}'
                    ? const Icon(Icons.check, color: AppTokens.brand)
                    : null,
                onTap: () => Navigator.pop(c, '${w['id']}'),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => warehouseId = picked.isEmpty ? null : picked);
    load();
  }

  Widget pill(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: selected ? AppTokens.brand : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTokens.ink,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final inventory = spec.key == 'inventory';
    final warehouseName = warehouses
        .where((w) => '${w['id']}' == warehouseId)
        .map((w) => '${w['name']}')
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: OrgTitle(widget.session, spec.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      hintText: inventory
                          ? '搜索物料编码'
                          : spec.key == 'picking'
                          ? '生产订单 ID'
                          : '搜索单据号',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: ListenableBuilder(
                        listenable: search,
                        builder: (_, _) => search.text.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                tooltip: '清除',
                                icon: const Icon(Icons.cancel, size: 18),
                                onPressed: () {
                                  search.clear();
                                  load();
                                },
                              ),
                      ),
                    ),
                    onSubmitted: (_) => load(),
                  ),
                ),
                if (inventory) ...[
                  const SizedBox(width: 10),
                  Material(
                    color: AppTokens.brand,
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                      onTap: scan,
                      child: const Tooltip(
                        message: '扫码查询',
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (spec.statuses.isNotEmpty || warehouses.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (warehouses.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: warehouseId == null
                            ? Colors.white
                            : AppTokens.brandSoft,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: chooseWarehouse,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warehouse_outlined,
                                  size: 16,
                                  color: AppTokens.brand,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  warehouseName ?? '全部仓库',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTokens.brand,
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: AppTokens.brand,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (spec.statuses.isNotEmpty) ...[
                    pill('全部', status == null, () {
                      setState(() => status = null);
                      load();
                    }),
                    for (var i = 0; i < spec.statuses.length; i++)
                      pill(spec.statuses[i], status == i, () {
                        setState(() => status = i);
                        load();
                      }),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Row(
              children: [
                Text(
                  loading ? '加载中…' : '共 $total 条',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : RefreshIndicator(
                    onRefresh: () => load(),
                    child: ListView(
                      key: PageStorageKey(spec.key),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (error != null)
                          StateNotice(
                            error!,
                            retry: () => load(append: rows.isNotEmpty),
                          ),
                        if (rows.isEmpty && error == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: StateNotice('没有符合条件的记录，请调整搜索条件'),
                          ),
                        for (final row in rows)
                          RecordCard(
                            spec,
                            row,
                            onTap: !widget.session.can(spec.detailPermission)
                                ? () => feedback(context, '没有查看详情权限')
                                : () async {
                                    await context.push(
                                      '/workspace/${spec.key}/${row['id']}',
                                    );
                                    if (mounted) load();
                                  },
                          ),
                        if (rows.length < total)
                          TextButton(
                            onPressed: more ? null : () => load(append: true),
                            child: Text(
                              more ? '加载中…' : '加载更多（${rows.length}/$total）',
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
