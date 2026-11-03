import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';
import 'brand.dart';
import 'theme.dart';

class StateNotice extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const StateNotice(this.message, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 32, color: AppTokens.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('重试')),
        ],
      ),
    ),
  );
}

class AsyncPane extends StatelessWidget {
  final bool loading;
  final Object? error;
  final VoidCallback retry;
  final Widget child;
  const AsyncPane({
    super.key,
    required this.loading,
    required this.error,
    required this.retry,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator.adaptive())
      : error != null
      ? StateNotice(error.toString(), retry: retry)
      : child;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showAdaptiveDialog<bool>(
      context: context,
      builder: (c) => AlertDialog.adaptive(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          adaptiveAction(c, '返回核对', () => Navigator.pop(c, false)),
          adaptiveAction(c, '确认', () => Navigator.pop(c, true), primary: true),
        ],
      ),
    ) ??
    false;
Widget adaptiveAction(
  BuildContext context,
  String label,
  VoidCallback onPressed, {
  bool primary = false,
}) {
  final style = primary ? const TextStyle(fontWeight: FontWeight.w600) : null;
  return Theme.of(context).platform == TargetPlatform.iOS
      ? CupertinoDialogAction(
          onPressed: onPressed,
          isDefaultAction: primary,
          child: Text(label),
        )
      : TextButton(
          onPressed: onPressed,
          child: Text(label, style: style),
        );
}

void feedback(BuildContext context, Object message) {
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.toString())));
  }
}

class OrgTitle extends StatelessWidget {
  final Session session;
  final String title;
  const OrgTitle(this.session, this.title, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(title, style: const TextStyle(height: 1.25)),
      Text(
        session.organization['name']?.toString() ?? '',
        style: const TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w400,
          color: AppTokens.muted,
        ),
      ),
    ],
  );
}

class DataFields extends StatelessWidget {
  final Json data;
  const DataFields(this.data, {super.key});
  static const labels = {
    'productionOrderNo': '生产订单',
    'productionReportNo': '报工单号',
    'pickingNo': '领料单号',
    'warehousingNo': '入库单号',
    'purchaseInStockNo': '采购入库单',
    'purchaseOrderNo': '采购订单',
    'deliveryNo': '出库单号',
    'orderNo': '订单号',
    'salesOrderNo': '销售订单',
    'customerName': '客户',
    'supplierName': '供应商',
    'materialCode': '物料编码',
    'materialName': '物料名称',
    'warehouseName': '仓库',
    'storageLocation': '库位',
    'batchNo': '批次',
    'plannedQuantity': '计划数量',
    'completedQuantity': '已完成数量',
    'actualQuantity': '实际数量',
    'reportQuantity': '报工量',
    'qualifiedQuantity': '合格量',
    'scrappedQuantity': '报废量',
    'warehousingQuantity': '入库数量',
    'inQuantity': '采购入库量',
    'quantity': '数量',
    'onHand': '在库',
    'reserved': '预留',
    'available': '可用',
    'reservedQuantity': '预留量',
    'reportUserName': '报工人',
    'reportTime': '报工时间',
    'plannedStartTime': '计划开始',
    'plannedEndTime': '计划结束',
    'actualStartTime': '实际开始',
    'actualEndTime': '实际结束',
    'deliveryDate': '交付日期',
    'remark': '备注',
  };
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final e in labels.entries)
        if (data[e.key] != null && data[e.key].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth < 280
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.value,
                          style: const TextStyle(color: AppTokens.muted),
                        ),
                        SelectableText('${data[e.key]}'),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            e.value,
                            style: const TextStyle(color: AppTokens.muted),
                          ),
                        ),
                        Expanded(child: SelectableText('${data[e.key]}')),
                      ],
                    ),
            ),
          ),
    ],
  );
}

class SectionGap extends StatelessWidget {
  const SectionGap({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

/// iOS 分组卡片：白底圆角，内容裁剪，水波纹显示在卡片内。
class GroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  const GroupCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? action;
  final int? count;
  final VoidCallback? onPressed;
  const SectionHeading(
    this.title, {
    super.key,
    this.action,
    this.count,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (count != null) StatusTag('$count'),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onPressed,
            child: Text(
              '$action ›',
              style: const TextStyle(fontSize: 12, color: AppTokens.muted),
            ),
          ),
      ],
    ),
  );
}

class StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const StatusTag(this.label, {super.key, this.color = AppTokens.brand});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color)),
  );
}

AppBar organizationBar(BuildContext context, Session session) => AppBar(
  toolbarHeight: MediaQuery.textScalerOf(context).scale(20) + 36,
  automaticallyImplyLeading: false,
  centerTitle: false,
  backgroundColor: AppTokens.canvas,
  titleSpacing: 20,
  title: InkWell(
    onTap: () async {
      if (await confirm(context, '切换组织', '将退出当前账号并重新登录，未提交内容将丢失。'))
        await session.logout();
    },
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const OriginLogo(size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${session.organization['name'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.keyboard_arrow_down, size: 12, color: AppTokens.muted),
      ],
    ),
  ),
  actions: [
    IconButton(
      tooltip: '搜索应用',
      onPressed: () => context.push('/workspace/apps'),
      icon: Icon(Icons.search, size: 21),
    ),
    IconButton(
      tooltip: '扫一扫',
      onPressed: () async {
        if (!session.can('inventory:material-stock:list')) {
          feedback(context, '没有库存查询权限');
          return;
        }
        final code = await context.push<String>('/scan');
        if (code != null && context.mounted)
          context.push(
            '/workspace/inventory?keyword=${Uri.encodeQueryComponent(code)}',
          );
      },
      icon: Icon(Icons.qr_code_scanner, size: 22),
    ),
    const SizedBox(width: 8),
  ],
);
