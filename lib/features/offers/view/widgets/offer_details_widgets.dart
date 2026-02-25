import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/reviews/models/reviews_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT INFO SECTION
// ─────────────────────────────────────────────────────────────────────────────

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

  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    final tierColor  = getTierColor(profile.tier);
    final tierLabel  = getTierLabel(profile.tier);
    final availColor = getAvailabilityColor(profile.availability);
    final availLabel = getAvailabilityLabel(profile.availability);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.storefront_outlined, size: 14, color: c.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Merchant',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),

                // Tier badge — solid fill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tierLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Availability
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: availColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      availLabel,
                      style: TextStyle(
                        color: availColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _SolidRule(c: c),
          const SizedBox(height: 14),

          // ── Name + rating block
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      if (profile.country != null && profile.country!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 12, color: c.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              profile.country!,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Rating block
                if (loadingReviews)
                  Container(
                    width: 64,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                  )
                else if (averageRating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: _amber),
                            const SizedBox(width: 4),
                            Text(
                              averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: _amber,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        if (reviewCount != null && reviewCount! > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$reviewCount reviews',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                profile.bio!,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // ── Payment methods
          if (paymentMethodIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.payment_rounded, size: 12, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paymentMethodIds.join(' · '),
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT INFO SKELETON
// ─────────────────────────────────────────────────────────────────────────────

class MerchantInfoSkeleton extends StatefulWidget {
  const MerchantInfoSkeleton({super.key, required this.c});
  final AppColor c;

  @override
  State<MerchantInfoSkeleton> createState() => _MerchantInfoSkeletonState();
}

class _MerchantInfoSkeletonState extends State<MerchantInfoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);
  late final Animation<double> _a =
  CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c       = widget.c;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final skeletonColor = isLight
            ? Color.lerp(const Color(0xFFE5E7EB), const Color(0xFFD1D5DB), _a.value)!
            : Color.lerp(const Color(0xFF2A2A2A), const Color(0xFF3A3A3A), _a.value)!;

        Widget box({required double w, required double h, required double r}) =>
            Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(r),
              ),
            );

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header bar
              Row(
                children: [
                  box(w: 28, h: 28, r: 8),
                  const SizedBox(width: 8),
                  box(w: 70, h: 13, r: 4),
                  const Spacer(),
                  box(w: 52, h: 22, r: 6),
                  const SizedBox(width: 10),
                  box(w: 64, h: 16, r: 5),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: c.border),
              const SizedBox(height: 14),
              // Name + rating row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        box(w: 150, h: 16, r: 4),
                        const SizedBox(height: 7),
                        box(w: 80, h: 11, r: 3),
                      ],
                    ),
                  ),
                  box(w: 72, h: 40, r: 10),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEWS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class ReviewsSection extends StatelessWidget {
  const ReviewsSection({
    super.key,
    required this.c,
    required this.reviews,
    this.averageRating,
  });

  final AppColor c;
  final List<ReviewModel> reviews;
  final double? averageRating;

  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    final recent     = reviews.take(3).toList();
    final totalCount = reviews.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: const Icon(Icons.star_rounded, size: 14, color: _amber),
                ),
                const SizedBox(width: 8),
                Text(
                  'Reviews',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),

                // Average score
                if (averageRating != null) ...[
                  Text(
                    averageRating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: _amber,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    ' / 5',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                // Count badge
                if (totalCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      '$totalCount',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (recent.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'No reviews yet',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _SolidRule(c: c),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: recent.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key < recent.length - 1 ? 10 : 0),
                  child: ReviewItem(c: c, review: e.value),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW ITEM
// ─────────────────────────────────────────────────────────────────────────────

class ReviewItem extends StatelessWidget {
  const ReviewItem({
    super.key,
    required this.c,
    required this.review,
    this.isLight,
  });

  final AppColor c;
  final ReviewModel review;
  final bool? isLight;

  static const _amber = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    final hasComment = review.comment != null && review.comment!.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 11, 12, hasComment ? 12 : 11),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Stars
              Row(
                children: List.generate(5, (i) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 13,
                    color: i < review.rating ? _amber : c.border,
                  ),
                )),
              ),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  _timeAgo(review.createdAt!),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (hasComment) ...[
            const SizedBox(height: 7),
            Text(
              review.comment!,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 30) return '${d.day}/${d.month}/${d.year}';
    if (diff.inDays > 0)  return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _SolidRule extends StatelessWidget {
  const _SolidRule({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: c.border);
}