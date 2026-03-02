import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offer_payment_method/offer_payment_method_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC OFFER TILE
// ─────────────────────────────────────────────────────────────────────────────

class PublicOfferTile extends StatefulWidget {
  const PublicOfferTile({
    super.key,
    required this.c,
    required this.offer,
    required this.marketPrice,
    required this.onTap,
    required this.shimmerAnim,
    this.priceLoading = false,
    this.enabled = true,
  });

  final AppColor c;
  final OfferModel offer;
  final String? marketPrice;
  final VoidCallback onTap;
  final Animation<double> shimmerAnim;
  final bool priceLoading;
  final bool enabled;

  @override
  State<PublicOfferTile> createState() => _PublicOfferTileState();
}

class _PublicOfferTileState extends State<PublicOfferTile>
    with SingleTickerProviderStateMixin {
  final _merchantCore = MerchantProfileCoreService.I;
  final _reviewsCore = ReviewsCoreService.I;
  final _offerPaymentCore = OfferPaymentMethodCoreService.I;

  MerchantProfileModel? _merchantProfile;
  bool _loadingMerchant = true;
  double? _averageRating;
  int _reviewCount = 0;
  bool _loadingReviews = true;
  Map<String, PaymentMethodModel> _paymentMethodsMap = {};
  bool _loadingPaymentMethods = true;

  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.975,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
    _loadData();
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() => Future.wait([
    _loadMerchantProfile(),
    _loadReviews(),
    _loadPaymentMethods(),
  ]);

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await _offerPaymentCore.getPaymentMethodsForOffer(
        widget.offer.id,
      );
      if (mounted) {
        setState(() {
          _paymentMethodsMap = {for (final m in methods) m.id: m};
          _loadingPaymentMethods = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPaymentMethods = false);
    }
  }

  String _paymentNames(List<String> ids) =>
      ids.map((id) => _paymentMethodsMap[id]?.name ?? id).take(3).join(' · ');

  Future<void> _loadMerchantProfile() async {
    final sid = widget.offer.sellerId;
    if (sid == null || sid.isEmpty) {
      if (mounted) setState(() => _loadingMerchant = false);
      return;
    }
    try {
      final p = await _merchantCore.getPublic(sid);
      if (mounted) {
        setState(() {
          _merchantProfile = p;
          _loadingMerchant = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMerchant = false);
    }
  }

  Future<void> _loadReviews() async {
    final sid = widget.offer.sellerId;
    if (sid == null || sid.isEmpty) {
      if (mounted) setState(() => _loadingReviews = false);
      return;
    }
    try {
      final avg = await _reviewsCore.getUserAverageRating(sid);
      final count = await _reviewsCore.getUserReviewCount(sid);
      if (mounted) {
        setState(() {
          _averageRating = avg;
          _reviewCount = count;
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  bool get _isBuy => widget.offer.type == OfferType.sell;

  Color get _typeColor => _isBuy ? widget.c.success : widget.c.error;

  Color _statusColor(String s) => switch (s.toUpperCase()) {
    'ACTIVE' => widget.c.success,
    'PAUSED' => widget.c.warning,
    'COMPLETED' => widget.c.primary,
    'CANCELLED' => widget.c.error,
    _ => widget.c.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final offer = widget.offer;
    final typeColor = _typeColor;
    final statusText = offer.status?.name.toUpperCase() ?? 'UNKNOWN';
    final enabled = widget.enabled;

    return GestureDetector(
      onTapDown: enabled ? (_) => _pressCtrl.forward() : null,
      onTapUp: enabled
          ? (_) {
              _pressCtrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: enabled ? () => _pressCtrl.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.48,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: c.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: c.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 3px top accent bar
                  Container(height: 3, color: typeColor),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Merchant Row
                        _MerchantRow(
                          c: c,
                          isBuy: _isBuy,
                          typeColor: typeColor,
                          statusText: statusText,
                          statusColor: _statusColor(statusText),
                          merchantProfile: _merchantProfile,
                          loadingMerchant: _loadingMerchant,
                          averageRating: _averageRating,
                          reviewCount: _reviewCount,
                          loadingReviews: _loadingReviews,
                          shimmerAnim: widget.shimmerAnim,
                        ),

                        const SizedBox(height: 10),
                        _SolidDivider(c: c),
                        const SizedBox(height: 10),

                        // ── Price Row
                        _PriceRow(
                          c: c,
                          offer: offer,
                          typeColor: typeColor,
                          marketPrice: widget.marketPrice,
                          priceLoading: widget.priceLoading,
                          shimmerAnim: widget.shimmerAnim,
                        ),

                        const SizedBox(height: 10),
                        _SolidDivider(c: c),
                        const SizedBox(height: 10),

                        // ── Footer Row
                        _FooterRow(
                          c: c,
                          offer: offer,
                          typeColor: typeColor,
                          isBuy: _isBuy,
                          loadingPaymentMethods: _loadingPaymentMethods,
                          paymentMethodsMap: _paymentMethodsMap,
                          paymentNames: _paymentNames,
                          shimmerAnim: widget.shimmerAnim,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.c,
    required this.isBuy,
    required this.typeColor,
    required this.statusText,
    required this.statusColor,
    required this.merchantProfile,
    required this.loadingMerchant,
    required this.averageRating,
    required this.reviewCount,
    required this.loadingReviews,
    required this.shimmerAnim,
  });

  final AppColor c;
  final bool isBuy;
  final Color typeColor;
  final String statusText;
  final Color statusColor;
  final MerchantProfileModel? merchantProfile;
  final bool loadingMerchant;
  final double? averageRating;
  final int reviewCount;
  final bool loadingReviews;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Direction badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Icon(
            isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 16,
            color: typeColor,
          ),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: loadingMerchant
              ? _MerchantSkeleton(c: c, shimmerAnim: shimmerAnim)
              : merchantProfile != null
              ? _MerchantMeta(
                  c: c,
                  profile: merchantProfile!,
                  averageRating: averageRating,
                  reviewCount: reviewCount,
                  loadingReviews: loadingReviews,
                  shimmerAnim: shimmerAnim,
                )
              : Text(
                  'Unknown merchant',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
        ),

        const SizedBox(width: 10),

        _Pill(
          label: statusText,
          textColor: c.onPrimary,
          bg: statusColor,
          fontSize: 9.5,
          weight: FontWeight.w800,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT META
// ─────────────────────────────────────────────────────────────────────────────

class _MerchantMeta extends StatelessWidget {
  const _MerchantMeta({
    required this.c,
    required this.profile,
    required this.averageRating,
    required this.reviewCount,
    required this.loadingReviews,
    required this.shimmerAnim,
  });

  final AppColor c;
  final MerchantProfileModel profile;
  final double? averageRating;
  final int reviewCount;
  final bool loadingReviews;
  final Animation<double> shimmerAnim;

  static const _tierLabel = {
    MerchantTier.bronze: 'BRONZE',
    MerchantTier.silver: 'SILVER',
    MerchantTier.gold: 'GOLD',
    MerchantTier.platinum: 'PLATINUM',
    MerchantTier.diamond: 'DIAMOND',
  };
  Map<MerchantTier, Color> get _tierColor => {
    MerchantTier.diamond: c.info,
    MerchantTier.platinum: c.textSecondary,
    MerchantTier.gold: c.warning,
    MerchantTier.silver: c.accent,
    MerchantTier.bronze: c.error,
  };
  static const _tierIcon = {
    MerchantTier.bronze: Icons.shield_outlined,
    MerchantTier.silver: Icons.workspace_premium_outlined,
    MerchantTier.gold: Icons.emoji_events_outlined,
    MerchantTier.platinum: Icons.military_tech_outlined,
    MerchantTier.diamond: Icons.diamond_outlined,
  };
  Map<SellerAvailability, Color> get _availColor => {
    SellerAvailability.available: c.success,
    SellerAvailability.unavailable: c.textSecondary,
    SellerAvailability.onBreak: c.warning,
    SellerAvailability.unknown: c.textSecondary,
  };
  static const _availLabel = {
    SellerAvailability.available: 'Online',
    SellerAvailability.unavailable: 'Offline',
    SellerAvailability.onBreak: 'On Break',
    SellerAvailability.unknown: 'Offline',
  };

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor[profile.tier]!;
    final availColor = _availColor[profile.availability]!;
    final availText = _availLabel[profile.availability]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + tier badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                profile.displayName,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.4,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 7),
            _Pill(
              label: _tierLabel[profile.tier]!,
              textColor: c.onPrimary,
              bg: tierColor,
              icon: _tierIcon[profile.tier],
              fontSize: 9,
              weight: FontWeight.w700,
            ),
          ],
        ),

        const SizedBox(height: 5),

        // Location · Rating · Availability
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (profile.country != null && profile.country!.isNotEmpty) ...[
              Icon(Icons.place_outlined, size: 11, color: c.textSecondary),
              const SizedBox(width: 2),
              Text(
                profile.country!,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _MetaDot(c: c),
            ],
            if (loadingReviews)
              _SkimBox(c: c, w: 42, h: 10, r: 3, anim: shimmerAnim)
            else ...[
              Icon(Icons.star_rounded, size: 11, color: c.warning),
              const SizedBox(width: 2),
              Text(
                (averageRating ?? 5.0).toStringAsFixed(1),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '(${_formatCount(reviewCount)})',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
              _MetaDot(c: c),
            ],
            // Availability dot + label
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: availColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              availText,
              style: TextStyle(
                color: availColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatCount(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k'
      : '$n';
}

class _MerchantSkeleton extends StatelessWidget {
  const _MerchantSkeleton({required this.c, required this.shimmerAnim});
  final AppColor c;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SkimBox(c: c, w: 120, h: 13, r: 4, anim: shimmerAnim),
      const SizedBox(height: 7),
      _SkimBox(c: c, w: 80, h: 10, r: 3, anim: shimmerAnim),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PRICE ROW
// ─────────────────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.c,
    required this.offer,
    required this.typeColor,
    required this.marketPrice,
    required this.priceLoading,
    required this.shimmerAnim,
  });

  final AppColor c;
  final OfferModel offer;
  final Color typeColor;
  final String? marketPrice;
  final bool priceLoading;
  final Animation<double> shimmerAnim;

  String? get _marginBadge {
    final m = offer.marginPercent;
    if (m == null || m == 0) return null;
    return '${m > 0 ? '+' : ''}${m.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final hasPrice = marketPrice != null;
    final margin = _marginBadge;

    // Price chip
    final priceChip = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasPrice ? typeColor : c.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasPrice ? typeColor : c.border),
      ),
      child: hasPrice
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.onPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Text(
                    marketPrice!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: -0.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            )
          : priceLoading
          ? _SkimBox(c: c, w: 72, h: 13, r: 4, anim: shimmerAnim)
          : Text(
              '—',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pair + margin badge
              Wrap(
                spacing: 8,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: offer.asset,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${offer.fiatCurrency.toUpperCase()}',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (margin != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        margin,
                        style: TextStyle(
                          color: c.onPrimary,
                          fontSize: 9.8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              // Min · Max limits
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LimitText(c: c, prefix: 'Min', value: offer.minAmount),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: c.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  _LimitText(c: c, prefix: 'Max', value: offer.maxAmount),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 148),
          child: priceChip,
        ),
      ],
    );
  }
}

class _LimitText extends StatelessWidget {
  const _LimitText({
    required this.c,
    required this.prefix,
    required this.value,
  });
  final AppColor c;
  final String prefix;
  final dynamic value;

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text: '$prefix ',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 10.8,
            fontWeight: FontWeight.w400,
          ),
        ),
        TextSpan(
          text: value != null ? '$value' : '—',
          style: TextStyle(
            color: value != null ? c.textPrimary : c.textSecondary,
            fontSize: 10.8,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER ROW
// ─────────────────────────────────────────────────────────────────────────────

class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.c,
    required this.offer,
    required this.typeColor,
    required this.isBuy,
    required this.loadingPaymentMethods,
    required this.paymentMethodsMap,
    required this.paymentNames,
    required this.shimmerAnim,
  });

  final AppColor c;
  final OfferModel offer;
  final Color typeColor;
  final bool isBuy;
  final bool loadingPaymentMethods;
  final Map<String, PaymentMethodModel> paymentMethodsMap;
  final String Function(List<String>) paymentNames;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) {
    final effectiveIds = paymentMethodsMap.isNotEmpty
        ? paymentMethodsMap.keys.toList()
        : offer.paymentMethodIds;
    final rate = offer.successRate;
    final successRateLabel = rate == null
        ? null
        : '${rate.toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Pill(
                    label: isBuy ? 'BUY' : 'SELL',
                    textColor: c.onPrimary,
                    bg: typeColor,
                    fontSize: 10,
                    weight: FontWeight.w800,
                  ),
                  if (successRateLabel != null)
                    _InfoChip(
                      c: c,
                      icon: Icons.verified_rounded,
                      iconColor: c.success,
                      text: '$successRateLabel success',
                    ),
                  if (offer.availableQty != null)
                    _InfoChip(
                      c: c,
                      icon: Icons.layers_outlined,
                      iconColor: c.textSecondary,
                      text: '${offer.availableQty} avail.',
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Chevron button
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: c.border),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: c.textSecondary,
              ),
            ),
          ],
        ),

        if (loadingPaymentMethods || effectiveIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (loadingPaymentMethods)
            _SkimBox(c: c, w: 110, h: 11, r: 4, anim: shimmerAnim)
          else
            _PaymentRow(
              c: c,
              methods: effectiveIds
                  .map((id) => paymentMethodsMap[id])
                  .whereType<PaymentMethodModel>()
                  .toList(),
              fallbackNames: paymentNames(effectiveIds),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.c,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final AppColor c;
  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: iconColor),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 116),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.c,
    required this.methods,
    required this.fallbackNames,
  });

  final AppColor c;
  final List<PaymentMethodModel> methods;
  final String fallbackNames;

  List<Color> get _logoColors => [
    c.primary,
    c.primary,
    c.success,
    c.warning,
    c.error,
  ];

  @override
  Widget build(BuildContext context) {
    final hasLogos = methods.any((m) => m.logo != null && m.logo!.isNotEmpty);

    if (!hasLogos) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 12,
            color: c.textSecondary,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              fallbackNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    const maxLogos = 3;
    final shown = methods.take(maxLogos).toList();
    final extra = methods.length - maxLogos;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Overlapping logo stack
        SizedBox(
          width: shown.length * 18.0 + 6,
          height: 24,
          child: Stack(
            children: shown
                .asMap()
                .entries
                .map(
                  (e) => Positioned(
                    left: e.key * 18.0,
                    child: _LogoAvatar(
                      method: e.value,
                      c: c,
                      size: 24,
                      fallbackColor: _logoColors[e.key % _logoColors.length],
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        if (extra > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$extra more',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else if (methods.length == 1) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              methods.first.name,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              shown.map((m) => m.name).join(' · '),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({
    required this.method,
    required this.c,
    required this.fallbackColor,
    this.size = 24,
  });

  final PaymentMethodModel method;
  final AppColor c;
  final Color fallbackColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = method.logo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: logo != null && logo.isNotEmpty ? c.background : fallbackColor,
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: c.surface, width: 2),
      ),
      child: logo != null && logo.isNotEmpty
          ? Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: Image.network(
                logo,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _fallbackText(),
              ),
            )
          : _fallbackText(),
    );
  }

  Widget _fallbackText() => Center(
    child: Text(
      method.name.isNotEmpty ? method.name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: size * 0.40,
        fontWeight: FontWeight.w800,
        color: c.onPrimary,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _SolidDivider extends StatelessWidget {
  const _SolidDivider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: c.border);
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.textColor,
    required this.bg,
    required this.fontSize,
    required this.weight,
    this.icon,
  });

  final String label;
  final Color textColor;
  final Color bg;
  final double fontSize;
  final FontWeight weight;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize + 2, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: weight,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Container(
      width: 2.5,
      height: 2.5,
      decoration: BoxDecoration(color: c.border, shape: BoxShape.circle),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER BOX
// ─────────────────────────────────────────────────────────────────────────────

class _SkimBox extends StatelessWidget {
  const _SkimBox({
    required this.c,
    required this.w,
    required this.h,
    required this.r,
    required this.anim,
  });

  final AppColor c;
  final double w, h, r;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? c.border.withValues(alpha: 0.52)
        : c.background.withValues(alpha: 0.98);
    final highlight = isDark
        ? c.textPrimary.withValues(alpha: 0.20)
        : c.onPrimary.withValues(alpha: 0.72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: base),
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                final bandWidth = w * 0.52;
                final travel = w + (bandWidth * 2);
                final left = (travel * anim.value) - bandWidth;
                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: bandWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              highlight.withValues(alpha: 0),
                              highlight,
                              highlight.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
