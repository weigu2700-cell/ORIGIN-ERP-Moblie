import 'package:flutter/material.dart';

import '../core/session.dart';
import '../domain/documents.dart';
import 'common.dart';
import 'theme.dart';

/// 数量显示：服务端返回 0.3000 这类小数，去掉多余的 0，保留最多四位。
String fmtNum(dynamic value) {
  if (value == null) return '—';
  final n = value is num ? value : num.tryParse('$value');
  if (n == null) return '$value';
  var text = n.toStringAsFixed(4);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = text.split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.join('.');
}

enum Tone { neutral, info, warn, good, bad }

Color toneColor(Tone tone) => switch (tone) {
  Tone.neutral => const Color(0xFF6F7F89),
  Tone.info => AppTokens.brand,
  Tone.warn => AppTokens.accent,
  Tone.good => const Color(0xFF2A8C6A),
  Tone.bad => const Color(0xFFC44F4F),
};

/// 按状态文案推断色调，避免每个单据各写一份映射。
Tone statusTone(String label) {
  if (label.contains('取消') || label.contains('驳回')) return Tone.bad;
  if (label.contains('草稿')) return Tone.neutral;
  if (label.contains('完成') ||
      label.contains('已入库') ||
      label.contains('已领料') ||
      label.contains('已上架')) {
    return Tone.good;
  }
  if (label.contains('待') || label.contains('审')) {
    return Tone.warn;
  }
  return Tone.info;
}

class StatusPill extends StatelessWidget {
  final String label;
  final Tone? tone;
  const StatusPill(this.label, {super.key, this.tone});
  @override
  Widget build(BuildContext context) {
    final color = toneColor(tone ?? statusTone(label));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一组并排的数值：大号数字加说明。
class StatRow extends StatelessWidget {
  final List<({String label, String value, Color? color})> stats;
  const StatRow(this.stats, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) Container(width: 1, height: 28, color: AppTokens.line),
        Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stats[i].value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: stats[i].color ?? AppTokens.ink,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stats[i].label,
                style: const TextStyle(fontSize: 12, color: AppTokens.muted),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

/// 库存条：可用 / 预留占在库的比例。
class StockBar extends StatelessWidget {
  final num onHand, reserved;
  const StockBar(this.onHand, this.reserved, {super.key});
  @override
  Widget build(BuildContext context) {
    final total = onHand <= 0 ? 1 : onHand;
    final reservedShare = (reserved / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: ((1 - reservedShare) * 1000).round(),
              child: Container(
                color: onHand <= 0 ? AppTokens.line : toneColor(Tone.good),
              ),
            ),
            if (reservedShare > 0)
              Expanded(
                flex: (reservedShare * 1000).round(),
                child: Container(color: toneColor(Tone.warn)),
              ),
          ],
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const ProgressBar(this.value, {super.key, this.color = AppTokens.brand});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: 6,
      color: color,
      backgroundColor: AppTokens.line,
    ),
  );
}

num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

/// 列表卡片：库存与各类单据共用外框，内部按单据类型展示最有用的信息。
class RecordCard extends StatelessWidget {
  final DocSpec spec;
  final Json row;
  final VoidCallback onTap;
  const RecordCard(this.spec, this.row, {super.key, required this.onTap});

  Widget meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTokens.muted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: AppTokens.muted),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final title = '${row['materialName'] ?? row[spec.number] ?? '单据'}';
    final number = '${row[spec.number] ?? ''}';
    final inventory = spec.key == 'inventory';
    final status = spec.statuses.isEmpty
        ? null
        : spec.statusLabel(row['status']);
    final planned = _n(row['plannedQuantity']);
    final done = _n(row['completedQuantity']);
    return GroupCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (number.isNotEmpty && number != title) ...[
                          const SizedBox(height: 2),
                          SelectableText(
                            number,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTokens.muted,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    StatusPill(status),
                  ] else
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppTokens.muted,
                    ),
                ],
              ),
              if (inventory) ...[
                const SizedBox(height: 14),
                StatRow([
                  (
                    label: '可用',
                    value: fmtNum(row['available']),
                    color: _n(row['available']) > 0
                        ? toneColor(Tone.good)
                        : toneColor(Tone.bad),
                  ),
                  (label: '预留', value: fmtNum(row['reserved']), color: null),
                  (label: '在库', value: fmtNum(row['onHand']), color: null),
                ]),
                const SizedBox(height: 12),
                StockBar(_n(row['onHand']), _n(row['reserved'])),
              ] else if (planned > 0) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: ProgressBar(done / planned)),
                    const SizedBox(width: 10),
                    Text(
                      '${fmtNum(done)} / ${fmtNum(planned)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  if (row['warehouseName'] != null)
                    meta(Icons.warehouse_outlined, '${row['warehouseName']}'),
                  if (row['customerName'] != null)
                    meta(Icons.business_outlined, '${row['customerName']}'),
                  if (row['supplierName'] != null)
                    meta(
                      Icons.local_shipping_outlined,
                      '${row['supplierName']}',
                    ),
                  if (row['plannedEndTime'] != null)
                    meta(
                      Icons.event_outlined,
                      '计划完成 ${'${row['plannedEndTime']}'.split(' ').first}',
                    ),
                  if (row['deliveryDate'] != null)
                    meta(
                      Icons.event_outlined,
                      '交付 ${'${row['deliveryDate']}'.split(' ').first}',
                    ),
                  if (!inventory &&
                      row['materialName'] != null &&
                      row[spec.number] != null &&
                      number != title)
                    const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _baseKeys = [
  'productionOrderNo',
  'productionReportNo',
  'pickingNo',
  'warehousingNo',
  'purchaseInStockNo',
  'purchaseOrderNo',
  'deliveryNo',
  'orderNo',
  'salesOrderNo',
  'customerName',
  'supplierName',
  'materialCode',
  'materialName',
  'warehouseName',
  'storageLocation',
  'batchNo',
  'reportUserName',
  'remark',
];
const _quantityKeys = [
  'plannedQuantity',
  'completedQuantity',
  'actualQuantity',
  'reportQuantity',
  'qualifiedQuantity',
  'scrappedQuantity',
  'warehousingQuantity',
  'inQuantity',
  'quantity',
  'onHand',
  'reserved',
  'available',
  'reservedQuantity',
];
const _timeKeys = [
  'reportTime',
  'plannedStartTime',
  'plannedEndTime',
  'actualStartTime',
  'actualEndTime',
  'deliveryDate',
];

/// 详情分组：基本信息 / 数量 / 时间。没有任何字段的分组不显示。
List<Widget> infoSections(Json data, {Set<String> skip = const {}}) {
  Widget? section(String title, List<String> keys) {
    final rows = [
      for (final key in keys)
        if (!skip.contains(key) &&
            data[key] != null &&
            data[key].toString().isNotEmpty)
          key,
    ];
    if (rows.isEmpty) return null;
    return InfoCard(title, data, rows);
  }

  return [
    ?section('基本信息', _baseKeys),
    ?section('数量', _quantityKeys),
    ?section('时间', _timeKeys),
  ];
}

class InfoCard extends StatelessWidget {
  final String title;
  final Json data;
  final List<String> keys;
  const InfoCard(this.title, this.data, this.keys, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, color: AppTokens.muted),
          ),
        ),
        GroupCard(
          child: Column(
            children: [
              for (var i = 0; i < keys.length; i++) ...[
                if (i > 0) const Divider(indent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          DataFields.labels[keys[i]] ?? keys[i],
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTokens.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          _quantityKeys.contains(keys[i])
                              ? fmtNum(data[keys[i]])
                              : '${data[keys[i]]}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: _quantityKeys.contains(keys[i])
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// 状态进度：把单据状态画成一条时间线，当前步骤高亮。
class StatusSteps extends StatelessWidget {
  final List<String> steps;
  final int current;
  const StatusSteps(this.steps, this.current, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0)
          Expanded(
            child: Container(
              height: 2,
              color: i <= current ? AppTokens.brand : AppTokens.line,
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= current ? AppTokens.brand : Colors.white,
                border: Border.all(
                  color: i <= current ? AppTokens.brand : AppTokens.line,
                  width: 2,
                ),
              ),
              child: i < current
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              steps[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                color: i <= current ? AppTokens.ink : AppTokens.muted,
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
