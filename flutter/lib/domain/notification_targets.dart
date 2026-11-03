import 'package:origin_mobile/domain/documents.dart';

/// 只映射服务端实际发布的业务类型，未知类型保留为通知正文。
DocSpec? notificationTarget(String? businessType) {
  const targets = {
    'PRODUCTION_REPORT_PENDING_APPROVAL': 'reports',
    'PRODUCTION_REPORT_APPROVED': 'reports',
    'PRODUCTION_REPORT_REJECTED': 'reports',
    'PRODUCTION_PICKING_DART': 'picking',
    'PRODUCTION_PICKING_CONFIRM': 'picking',
    'PRODUCTION_PICKING_READY': 'picking',
    'FINISH_WAREHOUSING_PENDING_APPROVAL': 'warehousing',
    'PURCHASE_IN_STOCK_PENDING_APPROVAL': 'receiving',
    'PURCHASE_IN_STOCK_PENDING_UPLOAD': 'receiving',
    'SALES_DELIVERY_PENDING_OUTBOUND': 'deliveries',
    'SALES_ORDER_PENDING_CONFIRM': 'sales',
    'SALES_ORDER_CONFIRMED': 'sales',
    'SALES_ORDER_CANCELLED': 'sales',
    'SALES_ORDER_COMPLETED': 'sales',
  };
  final key = targets[businessType];
  if (key == null) return null;
  return documents.firstWhere((spec) => spec.key == key);
}
