/// Rupee formatting, shared across screens. Whole amounts drop the decimals;
/// everything else shows paise. Single definition so every screen agrees.
String rupees(num v) {
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  return '₹$s';
}
