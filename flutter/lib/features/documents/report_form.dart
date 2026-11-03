import 'package:flutter/material.dart';

import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/session.dart';
import 'package:origin_mobile/data/warehouse_repository.dart';
import 'package:origin_mobile/domain/quantity.dart';
import 'package:origin_mobile/domain/documents.dart';
import 'package:origin_mobile/features/documents/document_list.dart';
import 'package:origin_mobile/ui/cards.dart';
import 'package:origin_mobile/ui/common.dart';
import 'package:origin_mobile/ui/theme.dart';
import 'package:origin_mobile/data/production_repository.dart';

class ReportFormPage extends StatefulWidget {
  final Session session;
  final Json order;
  const ReportFormPage(this.session, this.order, {super.key});
  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  late final production = ProductionRepository(widget.session);
  final form = GlobalKey<FormState>();
  final report = TextEditingController(),
      qualified = TextEditingController(),
      scrapped = TextEditingController(text: '0'),
      remark = TextEditingController();
  List<Json> warehouses = [];
  String? warehouse, error;
  bool busy = false,
      loading = true,
      unknown = false,
      saved = false,
      canLeave = false;
  @override
  void initState() {
    super.initState();
    warehouse = widget.order['warehouseId']?.toString();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!widget.session.can('master:warehouse:list')) {
        throw const ApiFailure('缺少仓库查询权限，请联系管理员');
      }
      final enabled = await WarehouseRepository(widget.session).enabled();
      if (mounted) {
        setState(() {
          warehouses = enabled;
          if (!warehouses.any((w) => w['id'].toString() == warehouse)) {
            warehouse = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (busy || unknown || !form.currentState!.validate()) return;
    final validation = validateQuantities(
      report.text,
      qualified.text,
      scrapped.text,
    );
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() => busy = true);
    final ticket = widget.session.api.generation;
    try {
      if (!await confirm(
            context,
            '保存报工草稿',
            '订单：${widget.order['productionOrderNo']}\n报工 ${report.text} · 合格 ${qualified.text} · 报废 ${scrapped.text}\n保存不会审批报工或增加库存。',
          ) ||
          !mounted) {
        return;
      }
      widget.session.api.check(ticket);
      if (!widget.session.can('prd:report:add')) {
        throw const ApiFailure('没有新增报工权限');
      }
      final latest = await production.order(widget.order['id']);
      if (latest['status'] != 2) throw const ApiFailure('订单已不在生产中，请返回核对');
      await production.createReport({
        'productionOrderId': widget.order['id'].toString(),
        'materialId': widget.order['materialId'].toString(),
        'warehouseId': warehouse,
        'reportQuantity': report.text,
        'qualifiedQuantity': qualified.text,
        'scrappedQuantity': scrapped.text,
        'remark': remark.text,
      });
      if (mounted) {
        setState(() => saved = true);
        feedback(context, '报工草稿已保存，请在报工列表核对并审批');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          unknown = e is ApiFailure && e.unknownResult;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    report.dispose();
    qualified.dispose();
    scrapped.dispose();
    remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canLeave || saved,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || busy) return;
      if (await confirm(context, '离开报工登记', '未保存的数量与备注将丢失。确认返回？') && mounted) {
        setState(() => canLeave = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('登记报工'),
      ),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GroupCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.order['materialName']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.order['productionOrderNo']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTokens.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const StatusSteps(['草稿', '审批', '完成', '入库'], 0),
                      const SizedBox(height: 12),
                      const Text(
                        '保存只生成草稿，不会审批报工，也不会增加库存。',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (loading) const LinearProgressIndicator(),
              DropdownButtonFormField<String>(
                initialValue: warehouse,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '成品仓库'),
                items: [
                  for (final w in warehouses)
                    DropdownMenuItem(
                      value: w['id'].toString(),
                      child: Text(w['name'].toString()),
                    ),
                ],
                onChanged: busy ? null : (v) => warehouse = v,
                validator: (v) => v == null ? '请选择成品仓库' : null,
              ),
              const SizedBox(height: 18),
              for (final entry in [
                (report, '本次报工量'),
                (qualified, '合格量'),
                (scrapped, '报废量'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextFormField(
                    controller: entry.$1,
                    enabled: !busy && !unknown,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: entry.$2,
                      helperText: '最多四位小数',
                    ),
                    validator: (v) => quantityUnits(v ?? '') == null
                        ? '请输入非负数量，最多四位小数'
                        : null,
                  ),
                ),
              TextFormField(
                controller: remark,
                enabled: !busy && !unknown,
                decoration: const InputDecoration(labelText: '备注（选填）'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (unknown)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('请返回订单的关联报工列表核对是否保存成功；核对前不要再次登记。'),
                ),
              if (unknown)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentListPage(
                        widget.session,
                        documents.firstWhere((d) => d.key == 'reports'),
                        orderId: widget.order['id'].toString(),
                      ),
                    ),
                  ),
                  child: const Text('回查此订单的报工记录'),
                ),
              if (warehouses.isEmpty && !loading)
                TextButton(onPressed: load, child: const Text('重新加载仓库')),
              FilledButton(
                onPressed: busy || loading || unknown || saved ? null : save,
                child: Text(busy ? '正在保存…' : '保存草稿'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
