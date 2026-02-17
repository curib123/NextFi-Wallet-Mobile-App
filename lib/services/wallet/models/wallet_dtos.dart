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
    'publicAddress': publicAddress,
    'network': network,
    if (label != null) 'label': label,
  };
}

class UpdateWalletRequest {
  final String? label;

  UpdateWalletRequest({this.label});

  Map<String, dynamic> toJson() => {
    if (label != null) 'label': label,
  };
}
