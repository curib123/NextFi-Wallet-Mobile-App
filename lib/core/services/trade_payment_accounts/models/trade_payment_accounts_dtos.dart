class TradePaymentAccountsQuery {
  final bool? activeOnly;

  const TradePaymentAccountsQuery({this.activeOnly});

  Map<String, String> toQueryMap() => {
    if (activeOnly != null) 'activeOnly': activeOnly.toString(),
  };
}
