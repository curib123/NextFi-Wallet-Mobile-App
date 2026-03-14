import 'merchant_profile_models.dart';

class MerchantTierProgressModel {
  const MerchantTierProgressModel({
    required this.currentTier,
    required this.persistedTier,
    required this.minimumData,
    required this.metrics,
    required this.tiers,
    required this.nextTier,
  });

  final MerchantTier currentTier;
  final MerchantTier persistedTier;
  final MerchantTierMinimumData minimumData;
  final MerchantTierMetrics metrics;
  final List<MerchantTierProgressItem> tiers;
  final MerchantTierProgressItem? nextTier;

  factory MerchantTierProgressModel.fromJson(Map<String, dynamic> json) {
    final tiersRaw = _read(json, const ['tiers']);
    final tiers = tiersRaw is List
        ? tiersRaw
              .whereType<Map>()
              .map(
                (e) => MerchantTierProgressItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false)
        : const <MerchantTierProgressItem>[];

    final nextRaw = _read(json, const ['nextTier', 'next_tier']);
    return MerchantTierProgressModel(
      currentTier: merchantTierFromApi(
        _read(json, const ['currentTier', 'current_tier']),
      ),
      persistedTier: merchantTierFromApi(
        _read(json, const ['persistedTier', 'persisted_tier']),
      ),
      minimumData: MerchantTierMinimumData.fromJson(
        _asMap(_read(json, const ['minimumData', 'minimum_data'])),
      ),
      metrics: MerchantTierMetrics.fromJson(
        _asMap(_read(json, const ['metrics'])),
      ),
      tiers: tiers,
      nextTier: nextRaw is Map
          ? MerchantTierProgressItem.fromJson(
              Map<String, dynamic>.from(nextRaw),
            )
          : null,
    );
  }
}

class MerchantTierMinimumData {
  const MerchantTierMinimumData({
    required this.minOffers,
    required this.minReviews,
    required this.totalOffers,
    required this.totalReviews,
    required this.met,
  });

  final int minOffers;
  final int minReviews;
  final int totalOffers;
  final int totalReviews;
  final bool met;

  factory MerchantTierMinimumData.fromJson(Map<String, dynamic> json) {
    return MerchantTierMinimumData(
      minOffers: _toInt(_read(json, const ['minOffers', 'min_offers'])),
      minReviews: _toInt(_read(json, const ['minReviews', 'min_reviews'])),
      totalOffers: _toInt(_read(json, const ['totalOffers', 'total_offers'])),
      totalReviews: _toInt(
        _read(json, const ['totalReviews', 'total_reviews']),
      ),
      met: _toBool(_read(json, const ['met'])),
    );
  }
}

class MerchantTierMetrics {
  const MerchantTierMetrics({
    required this.avgOfferSuccessRate,
    required this.avgReviewRating,
  });

  final double avgOfferSuccessRate;
  final double avgReviewRating;

  factory MerchantTierMetrics.fromJson(Map<String, dynamic> json) {
    return MerchantTierMetrics(
      avgOfferSuccessRate: _toDouble(
        _read(json, const ['avgOfferSuccessRate', 'avg_offer_success_rate']),
      ),
      avgReviewRating: _toDouble(
        _read(json, const ['avgReviewRating', 'avg_review_rating']),
      ),
    );
  }
}

class MerchantTierProgressItem {
  const MerchantTierProgressItem({
    required this.tier,
    required this.reached,
    required this.requirements,
    required this.progress,
  });

  final MerchantTier tier;
  final bool reached;
  final MerchantTierRequirements requirements;
  final MerchantTierProgress progress;

  factory MerchantTierProgressItem.fromJson(Map<String, dynamic> json) {
    return MerchantTierProgressItem(
      tier: merchantTierFromApi(json['tier']),
      reached: _toBool(json['reached']),
      requirements: MerchantTierRequirements.fromJson(
        _asMap(json['requirements']),
      ),
      progress: MerchantTierProgress.fromJson(_asMap(json['progress'])),
    );
  }
}

class MerchantTierRequirements {
  const MerchantTierRequirements({
    required this.minSuccessRate,
    required this.minAvgRating,
  });

  final double minSuccessRate;
  final double minAvgRating;

  factory MerchantTierRequirements.fromJson(Map<String, dynamic> json) {
    return MerchantTierRequirements(
      minSuccessRate: _toDouble(
        _read(json, const ['minSuccessRate', 'min_success_rate']),
      ),
      minAvgRating: _toDouble(
        _read(json, const ['minAvgRating', 'min_avg_rating']),
      ),
    );
  }
}

class MerchantTierProgress {
  const MerchantTierProgress({
    required this.successRatePercent,
    required this.avgRatingPercent,
    required this.overallPercent,
    required this.remainingSuccessRate,
    required this.remainingAvgRating,
  });

  final double successRatePercent;
  final double avgRatingPercent;
  final double overallPercent;
  final double remainingSuccessRate;
  final double remainingAvgRating;

  factory MerchantTierProgress.fromJson(Map<String, dynamic> json) {
    return MerchantTierProgress(
      successRatePercent: _toDouble(
        _read(json, const ['successRatePercent', 'success_rate_percent']),
      ),
      avgRatingPercent: _toDouble(
        _read(json, const ['avgRatingPercent', 'avg_rating_percent']),
      ),
      overallPercent: _toDouble(
        _read(json, const ['overallPercent', 'overall_percent']),
      ),
      remainingSuccessRate: _toDouble(
        _read(json, const ['remainingSuccessRate', 'remaining_success_rate']),
      ),
      remainingAvgRating: _toDouble(
        _read(json, const ['remainingAvgRating', 'remaining_avg_rating']),
      ),
    );
  }
}

dynamic _read(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  final text = (v?.toString() ?? '').trim().toLowerCase();
  return text == 'true' || text == '1';
}
