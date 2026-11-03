/// 使用万分位整数进行数量比较，避免浮点加法误差。
BigInt? quantityUnits(String value) {
  if (!RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return BigInt.parse(parts[0]) * BigInt.from(10000) +
      BigInt.parse((parts.length == 2 ? parts[1] : '').padRight(4, '0'));
}

String? validateQuantities(String report, String qualified, String scrapped) {
  final r = quantityUnits(report),
      q = quantityUnits(qualified),
      s = quantityUnits(scrapped);
  if (r == null || q == null || s == null) return '数量须为非负数字，最多四位小数';
  if (r <= BigInt.zero) return '本次报工量必须大于零';
  if (q + s > r) return '合格量与报废量之和不能超过报工量';
  return null;
}
