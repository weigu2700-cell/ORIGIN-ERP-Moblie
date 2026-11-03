import 'package:flutter/material.dart';

import 'package:origin_mobile/data/document_repository.dart';
import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/data/warehouse_repository.dart';
import 'package:origin_mobile/domain/documents.dart';
import 'package:origin_mobile/ui/common.dart';
import 'package:origin_mobile/features/documents/document_list.dart';
import 'package:origin_mobile/features/documents/report_form.dart';
import 'package:go_router/go_router.dart';
import 'package:origin_mobile/ui/cards.dart';
import 'package:origin_mobile/ui/theme.dart';
import 'package:origin_mobile/features/workspace/workspace.dart' show appIcon;

class DocumentDetailPage extends StatefulWidget {
  final Session session;
  final DocSpec spec;
  final String id;
  const DocumentDetailPage(this.session, this.spec, this.id, {super.key});
  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  int loadSequence = 0;
  Json? data;
  Object? error;
  bool loading = true, busy = false, unknown = false;
  DocumentRepository get repo => DocumentRepository(widget.session);
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
    try {
      final value = await repo.detail(widget.spec, widget.id);
      if (mounted && ticket == loadSequence) setState(() => data = value);
    } catch (e) {
      if (mounted && ticket == loadSequence) setState(() => error = e);
    } finally {
      if (mounted && ticket == loadSequence) setState(() => loading = false);
    }
  }

  Future<Json?> uploadForm() async {
    try {
      repo.require('master:warehouse:list');
      final enabled = await WarehouseRepository(widget.session).enabled();
      if (!mounted) return null;
      final warehouses = enabled;
      String? selected = data?['warehouseId']?.toString();
      if (!warehouses.any((w) => w['id'].toString() == selected)) {
        selected = null;
      }
      final location = TextEditingController(
        text: data?['storageLocation']?.toString() ?? '',
      );
      final batch = TextEditingController(
        text: data?['batchNo']?.toString() ?? '',
      );
      final form = GlobalKey<FormState>();
      final body = await showDialog<Json>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('核对上架信息'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '目标仓库'),
                    items: [
                      for (final w in warehouses)
                        DropdownMenuItem(
                          value: w['id'].toString(),
                          child: Text(w['name'].toString()),
                        ),
                    ],
                    onChanged: (v) => selected = v,
                    validator: (v) => v == null ? '请选择仓库' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: location,
                    decoration: const InputDecoration(labelText: '库位'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '请输入库位' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: batch,
                    decoration: const InputDecoration(labelText: '批次（选填）'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(c, <String, dynamic>{
                    'warehouseId': selected,
                    '_warehouseName': warehouses.firstWhere(
                      (w) => w['id'].toString() == selected,
                    )['name'],
                    'storageLocation': location.text.trim(),
                    'batchNo': batch.text.trim(),
                  });
                }
              },
              child: const Text('下一步核对'),
            ),
          ],
        ),
      );
      // 对话框退出动画期间控制器仍可能被 TextField 使用，不立即销毁。
      Future.delayed(const Duration(seconds: 1), () {
        location.dispose();
        batch.dispose();
      });
      return body;
    } catch (e) {
      if (mounted) feedback(context, e);
      return null;
    }
  }

  Future<void> act(DocAction action) async {
    if (busy || unknown) return;
    setState(() => busy = true);
    final generation = widget.session.api.generation;
    try {
      Json? body;
      if (action.suffix == 'upload') {
        body = await uploadForm();
        if (body == null) return;
      }
      if (!mounted) return;
      final warehouseName = body?.remove('_warehouseName');
      final summary =
          '${data?[widget.spec.number]}\n${data?['materialName'] ?? ''}\n${data?['warehouseName'] ?? ''}\n${action.impact}${body == null ? '' : '\n仓库：$warehouseName · 库位：${body['storageLocation']}'}';
      if (!await confirm(context, action.label, summary) || !mounted) return;
      widget.session.api.check(generation);
      await repo.execute(widget.spec, widget.id, action, body: body);
      if (mounted) feedback(context, '${action.label}成功');
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = null;
          if (e is ApiFailure && e.unknownResult) unknown = true;
        });
        feedback(context, e);
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<DocAction> get allowed => widget.spec.actions
      .where(
        (a) => a.status == data?['status'] && widget.session.can(a.permission),
      )
      .toList();

  Future<void> openReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/production-reports/new'),
        builder: (_) => ReportFormPage(widget.session, data!),
      ),
    );
    if (mounted) load();
  }

  Future<void> scanCheck() async {
    final code = await context.push<String>(
      '/scan?expected=${Uri.encodeQueryComponent(data!['materialCode'].toString())}',
    );
    if (code != null && mounted) {
      feedback(context, '物料编码一致，请继续核对数量与仓库');
    }
  }

  Widget hero(BuildContext context, DocSpec spec, Json d) {
    final inventory = spec.key == 'inventory';
    final planned = d['plannedQuantity'] is num
        ? d['plannedQuantity'] as num
        : num.tryParse('${d['plannedQuantity']}') ?? 0;
    final done = d['completedQuantity'] is num
        ? d['completedQuantity'] as num
        : num.tryParse('${d['completedQuantity']}') ?? 0;
    final label = spec.statuses.isEmpty ? null : spec.statusLabel(d['status']);
    final statusIndex = int.tryParse('${d['status']}') ?? 0;
    final flow = [
      for (final name in spec.statuses)
        if (!name.contains('取消') && !name.contains('驳回')) name,
    ];
    final onFlow = label != null && flow.contains(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GroupCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d['materialName'] ?? d[spec.number] ?? widget.id}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (d[spec.number] != null && d['materialName'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: SelectableText(
                              '${d[spec.number]}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTokens.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (label != null) StatusPill(label),
                ],
              ),
              if (inventory) ...[
                const SizedBox(height: 18),
                StatRow([
                  (
                    label: '可用',
                    value: fmtNum(d['available']),
                    color: toneColor(Tone.good),
                  ),
                  (label: '预留', value: fmtNum(d['reserved']), color: null),
                  (label: '在库', value: fmtNum(d['onHand']), color: null),
                ]),
                const SizedBox(height: 14),
                StockBar(
                  d['onHand'] is num ? d['onHand'] as num : 0,
                  d['reserved'] is num ? d['reserved'] as num : 0,
                ),
              ] else if (spec.key == 'orders' && planned > 0) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      fmtNum(done),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ' / ${fmtNum(planned)}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTokens.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(done / planned * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTokens.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressBar(done / planned),
              ],
              if (onFlow && flow.length >= 3) ...[
                const SizedBox(height: 20),
                StatusSteps(flow, flow.indexOf(label)),
              ],
              if (label != null && !onFlow && statusIndex >= 0) ...[
                const SizedBox(height: 12),
                Text(
                  '该单据已$label，不再继续流转。',
                  style: const TextStyle(fontSize: 13, color: AppTokens.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget linkRow(IconData icon, String title, VoidCallback? onTap) => ListTile(
    leading: Icon(icon, color: AppTokens.brand),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: const Icon(Icons.chevron_right, color: AppTokens.muted),
    onTap: onTap,
  );

  Widget? actionBar() {
    if (data == null) return null;
    final spec = widget.spec;
    final canReport =
        spec.key == 'orders' &&
        data!['status'] == 2 &&
        widget.session.can('prd:report:add');
    final actions = allowed;
    if (!canReport && actions.isEmpty) return null;
    final disabled = busy || unknown;
    final secondary = canReport ? actions : actions.skip(1).toList();
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (secondary.length == 1) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radius),
                      ),
                    ),
                    onPressed: disabled ? null : () => act(secondary.first),
                    child: Text(secondary.first.label),
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (secondary.length > 1) ...[
                PopupMenuButton<DocAction>(
                  enabled: !disabled,
                  tooltip: '更多操作',
                  onSelected: act,
                  itemBuilder: (_) => [
                    for (final action in secondary)
                      PopupMenuItem(value: action, child: Text(action.label)),
                  ],
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTokens.line),
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                    ),
                    child: const Icon(Icons.more_horiz),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: disabled
                      ? null
                      : canReport
                      ? openReport
                      : () => act(actions.first),
                  child: Text(
                    busy
                        ? '处理中…'
                        : canReport
                        ? '登记报工'
                        : actions.first.label,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
        title: OrgTitle(widget.session, spec.title),
        actions: [
          IconButton(
            tooltip: '刷新单据',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: actionBar(),
      body: AsyncPane(
        loading: loading,
        error: error,
        retry: load,
        child: data == null
            ? const StateNotice('单据不存在')
            : ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                children: [
                  hero(context, spec, data!),
                  if (unknown)
                    StateNotice(
                      '执行结果未知。已尝试回查，请核对最新状态；此页面已锁定再次执行。',
                      retry: load,
                    ),
                  ...infoSections(
                    data!,
                    skip: {
                      spec.number,
                      if (spec.key == 'inventory') ...[
                        'onHand',
                        'reserved',
                        'available',
                      ],
                      if (spec.key == 'orders') ...[
                        'plannedQuantity',
                        'completedQuantity',
                      ],
                      'materialName',
                    },
                  ),
                  if (data!['items'] is List &&
                      (data!['items'] as List).isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        '明细',
                        style: TextStyle(fontSize: 13, color: AppTokens.muted),
                      ),
                    ),
                    for (final item in data!['items'] as List)
                      GroupCard(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: DataFields(item as Json),
                        ),
                      ),
                  ],
                  if ((spec.key == 'picking' &&
                          data!['materialCode'] != null) ||
                      spec.key == 'orders')
                    GroupCard(
                      child: Column(
                        children: [
                          if (spec.key == 'picking' &&
                              data!['materialCode'] != null)
                            linkRow(
                              Icons.qr_code_scanner,
                              '扫码核对物料',
                              busy ? null : scanCheck,
                            ),
                          if (spec.key == 'orders')
                            for (final related in documents.where(
                              (d) =>
                                  [
                                    'picking',
                                    'reports',
                                    'warehousing',
                                  ].contains(d.key) &&
                                  widget.session.can(d.permission),
                            ))
                              linkRow(
                                appIcon(related.key),
                                '查看关联${related.title}',
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentListPage(
                                      widget.session,
                                      related,
                                      orderId: widget.id,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
