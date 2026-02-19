import 'package:next_fi/services/offers/models/offers_models.dart';

enum DisputeStatus {
  open,
  underReview,
  resolvedBuyer,
  resolvedSeller,
  cancelled,
  unknown,
}

DisputeStatus disputeStatusFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'OPEN':
      return DisputeStatus.open;
    case 'UNDER_REVIEW':
      return DisputeStatus.underReview;
    case 'RESOLVED_BUYER':
      return DisputeStatus.resolvedBuyer;
    case 'RESOLVED_SELLER':
      return DisputeStatus.resolvedSeller;
    case 'CANCELLED':
      return DisputeStatus.cancelled;
    default:
      return DisputeStatus.unknown;
  }
}

class DisputeEvidenceModel {
  final String id;
  final String? imageUrl;
  final String? note;
  final String? uploadedById;
  final DateTime? createdAt;

  const DisputeEvidenceModel({
    required this.id,
    this.imageUrl,
    this.note,
    this.uploadedById,
    this.createdAt,
  });

  factory DisputeEvidenceModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    String? readNullable(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    return DisputeEvidenceModel(
      id: readNullable(const ['id']) ?? '',
      imageUrl: readNullable(const ['imageUrl', 'image_url', 'url']),
      note: readNullable(const ['note']),
      uploadedById: readNullable(const ['uploadedById', 'uploaded_by_id']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}

class DisputeModel {
  final String id;
  final String tradeId;
  final String userId;
  final DisputeStatus status;
  final String statusRaw;
  final String reason;
  final String? resolution;
  final OfferAsset? asset;
  final String? fiatCurrency;
  final List<DisputeEvidenceModel> evidences;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DisputeModel({
    required this.id,
    required this.tradeId,
    required this.userId,
    required this.status,
    required this.statusRaw,
    required this.reason,
    this.resolution,
    this.asset,
    this.fiatCurrency,
    this.evidences = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    String? readNullableString(List<String> keys) {
      final value = readString(keys);
      return value.isEmpty ? null : value;
    }

    List<DisputeEvidenceModel> readEvidences() {
      final candidates = [
        json['evidences'],
        json['evidence'],
        json['attachments'],
      ];
      for (final raw in candidates) {
        if (raw is! List) continue;
        return raw
            .whereType<Map<String, dynamic>>()
            .map(DisputeEvidenceModel.fromJson)
            .toList();
      }
      return const [];
    }

    final tradeObj = json['trade'] is Map<String, dynamic>
        ? json['trade'] as Map<String, dynamic>
        : null;
    final statusRaw = readString(const ['status'], fallback: 'UNKNOWN');

    return DisputeModel(
      id: readString(const ['id']),
      tradeId: readString(const ['tradeId', 'trade_id']),
      userId: readString(const ['userId', 'user_id']),
      status: disputeStatusFromApi(statusRaw),
      statusRaw: statusRaw,
      reason: readString(const ['reason']),
      resolution: readNullableString(const ['resolution']),
      asset: tradeObj == null ? null : offerAssetFromApi(tradeObj['asset']),
      fiatCurrency: tradeObj == null
          ? null
          : (tradeObj['fiatCurrency'] ?? tradeObj['fiat_currency'])?.toString(),
      evidences: readEvidences(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}
