class WalletListQuery {
  final String? q;
  final String? network;
  final int? page;
  final int? limit;

  const WalletListQuery({this.q, this.network, this.page, this.limit});

  Map<String, String> toQueryMap() => {
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (network != null && network!.trim().isNotEmpty)
      'network': network!.trim(),
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
  };
}

class CreateWalletRequest {
  final String publicAddress;
  final String network;
  final String? label;

  CreateWalletRequest({
    required this.publicAddress,
    this.network = 'stellar',
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'publicAddress': publicAddress.trim(),
    'network': network.trim(),
    if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
  };
}

class UpdateWalletRequest {
  final String? publicAddress;
  final String? network;
  final String? label;

  const UpdateWalletRequest({this.publicAddress, this.network, this.label});

  Map<String, dynamic> toJson() => {
    if (publicAddress != null && publicAddress!.trim().isNotEmpty)
      'publicAddress': publicAddress!.trim(),
    if (network != null && network!.trim().isNotEmpty)
      'network': network!.trim(),
    if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
  };
}
