class UpsertFcmTokenRequest {
  final String token;
  final String? deviceId;
  final String? platform;   // android | ios | web
  final String? appVersion;

  const UpsertFcmTokenRequest({
    required this.token,
    this.deviceId,
    this.platform,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
    'token': token,
    if (deviceId != null) 'deviceId': deviceId,
    if (platform != null) 'platform': platform,
    if (appVersion != null) 'appVersion': appVersion,
  };
}

class SendPushRequest {
  final String title;
  final String body;
  final Map<String, String>? data;

  const SendPushRequest({
    required this.title,
    required this.body,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    if (data != null) 'data': data,
  };
}

class SendPushToUserRequest extends SendPushRequest {
  final String userId;

  const SendPushToUserRequest({
    required this.userId,
    required super.title,
    required super.body,
    super.data,
  });

  @override
  Map<String, dynamic> toJson() => {
    'userId': userId,
    ...super.toJson(),
  };
}

class SendPushToTokenRequest extends SendPushRequest {
  final String token;

  const SendPushToTokenRequest({
    required this.token,
    required super.title,
    required super.body,
    super.data,
  });

  @override
  Map<String, dynamic> toJson() => {
    'token': token,
    ...super.toJson(),
  };
}
