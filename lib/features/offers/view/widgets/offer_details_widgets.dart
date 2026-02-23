import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/reviews/models/reviews_models.dart';

class MerchantInfoSection extends StatelessWidget {
  const MerchantInfoSection({
    super.key,
    required this.c,
    required this.profile,
    required this.getTierLabel,
    required this.getTierColor,
    required this.getAvailabilityLabel,
    required this.getAvailabilityColor,
    required this.paymentMethodIds,
    this.averageRating,
    this.reviewCount,
    this.loadingReviews = false,
  });

  final AppColor c;
  final MerchantProfileModel profile;
  final String Function(MerchantTier) getTierLabel;
  final Color Function(MerchantTier) getTierColor;
  final String Function(SellerAvailability) getAvailabilityLabel;
  final Color Function(SellerAvailability) getAvailabilityColor;
  final List<String> paymentMethodIds;
  final double? averageRating;
  final int? reviewCount;
  final bool loadingReviews;

  @override
  Widget build(BuildContext context) {
    final tierLabel = getTierLabel(profile.tier);
    final tierColor = getTierColor(profile.tier);
    final availabilityLabel = getAvailabilityLabel(profile.availability);
    final availabilityColor = getAvailabilityColor(profile.availability);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Merchant', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
              const Spacer(),
              // Tier badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: tierColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(tierLabel, style: TextStyle(color: tierColor, fontWeight: FontWeight.w700, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              // Rating
              if (loadingReviews)
                Container(width: 40, height: 12, decoration: BoxDecoration(color: c.border.withOpacity(0.15), borderRadius: BorderRadius.circular(2)))
              else if (averageRating != null) ...[
                Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFB800)),
                const SizedBox(width: 2),
                Text(averageRating!.toStringAsFixed(1), style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                if (reviewCount != null && reviewCount! > 0)
                  Text(' ($reviewCount)', style: TextStyle(color: c.textSecondary, fontSize: 10)),
                const SizedBox(width: 8),
              ],
              // Availability indicator
              Container(width: 8, height: 8, decoration: BoxDecoration(color: availabilityColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(availabilityLabel, style: TextStyle(color: availabilityColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(profile.displayName, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          if (profile.country != null && profile.country!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 12, color: c.textSecondary),
              const SizedBox(width: 2),
              Text(profile.country!, style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ]),
          ],
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(profile.bio!, style: TextStyle(color: c.textSecondary, fontSize: 11.5), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          // Payment methods in merchant section
          if (paymentMethodIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.payment_rounded, size: 12, color: c.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(paymentMethodIds.join(', '), style: TextStyle(color: c.textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ],
      ),
    );
  }
}

class MerchantInfoSkeleton extends StatelessWidget {
  const MerchantInfoSkeleton({super.key, required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(color: c.border.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    );
  }
}

class ReviewsSection extends StatelessWidget {
  const ReviewsSection({super.key, required this.c, required this.reviews, this.averageRating});

  final AppColor c;
  final List<ReviewModel> reviews;
  final double? averageRating;

  @override
  Widget build(BuildContext context) {
    final recentReviews = reviews.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Reviews', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            const Spacer(),
            if (averageRating != null) ...[
              Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFB800)),
              const SizedBox(width: 2),
              Text(averageRating!.toStringAsFixed(1), style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ]),
          const SizedBox(height: 8),
          ...recentReviews.map((review) => Padding(padding: const EdgeInsets.only(bottom: 8), child: ReviewItem(c: c, review: review))),
        ],
      ),
    );
  }
}

class ReviewItem extends StatelessWidget {
  const ReviewItem({super.key, required this.c, required this.review});

  final AppColor c;
  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Row(children: List.generate(5, (index) {
              return Icon(
                index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 12,
                color: index < review.rating ? const Color(0xFFFFB800) : c.textSecondary.withOpacity(0.5),
              );
            })),
            const Spacer(),
            if (review.createdAt != null)
              Text(_formatDate(review.createdAt!), style: TextStyle(color: c.textSecondary, fontSize: 9)),
          ]),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment!, style: TextStyle(color: c.textPrimary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 30) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}
