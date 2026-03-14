class UpdateFeeConfigRequest {
  const UpdateFeeConfigRequest({
    this.profitAddress,
    this.txFeeUsd,
    this.swapFeePercent,
    this.isEnabled,
  });

  final String? profitAddress;
  final double? txFeeUsd;
  final double? swapFeePercent;
  final bool? isEnabled;

  Map<String, dynamic> toJson() => {
    if (profitAddress != null && profitAddress!.trim().isNotEmpty)
      'profitAddress': profitAddress!.trim(),
    if (txFeeUsd != null) 'txFeeUsd': txFeeUsd,
    if (swapFeePercent != null) 'swapFeePercent': swapFeePercent,
    if (isEnabled != null) 'isEnabled': isEnabled,
  };
}
