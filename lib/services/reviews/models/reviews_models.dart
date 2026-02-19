import 'package:next_fi/services/offers/models/offers_models.dart';

class ReviewModel {
  final String id;
  final String tradeId;
  final String reviewerId;
  final int rating;
  final String? comment;
  final OfferAsset? asset;
  final String? fiatCurrency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.tradeId,
    required this.reviewerId,
    required this.rating,
    this.comment,
    this.asset,
    this.fiatCurrency,
    this.createdAt,
    this.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
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

    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    String? readNullableString(List<String> keys) {
      final value = readString(keys);
      return value.isEmpty ? null : value;
    }

    final tradeObj = json['trade'] is Map<String, dynamic>
        ? json['trade'] as Map<String, dynamic>
        : null;

    return ReviewModel(
      id: readString(const ['id']),
      tradeId: readString(const ['tradeId', 'trade_id']),
      reviewerId: readString(const [
        'reviewerId',
        'reviewer_id',
        'userId',
        'user_id',
      ]),
      rating: readInt(const ['rating']),
      comment: readNullableString(const ['comment']),
      asset: tradeObj == null ? null : offerAssetFromApi(tradeObj['asset']),
      fiatCurrency: tradeObj == null
          ? null
          : (tradeObj['fiatCurrency'] ?? tradeObj['fiat_currency'])?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}
