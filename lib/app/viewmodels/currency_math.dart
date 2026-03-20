class CurrencyMath {
  static double sanitize(double value) {
    if (!value.isFinite || value.isNaN) return 0.0;
    return value;
  }

  static double assetAmountToFiat({
    required double amount,
    required double unitPrice,
  }) {
    final safeAmount = sanitize(amount);
    final safeUnitPrice = sanitize(unitPrice);
    if (safeAmount <= 0 || safeUnitPrice <= 0) return 0.0;
    return safeAmount * safeUnitPrice;
  }
}
