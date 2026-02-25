import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offer_payment_method/offer_payment_method_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';

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
  final _merchantCore     = MerchantProfileCoreService.I;
  final _reviewsCore      = ReviewsCoreService.I;
  final _offerPaymentCore = OfferPaymentMethodCoreService.I;

  MerchantProfileModel? _merchantProfile;
  bool _loadingMerchant = true;
  double? _averageRating;
  int _reviewCount = 0;
  bool _loadingReviews = true;
  Map<String, PaymentMethodModel> _paymentMethodsMap = {};
  bool _loadingPaymentMethods = true;

  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
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
      final methods = await _offerPaymentCore.getPaymentMethodsForOffer(widget.offer.id);
      if (mounted) setState(() {
        _paymentMethodsMap     = {for (final m in methods) m.id: m};
        _loadingPaymentMethods = false;
      });
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
      if (mounted) setState(() { _merchantProfile = p; _loadingMerchant = false; });
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
      final avg   = await _reviewsCore.getUserAverageRating(sid);
      final count = await _reviewsCore.getUserReviewCount(sid);
      if (mounted) setState(() {
        _averageRating  = avg;
        _reviewCount    = count;
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  bool get _isBuy => widget.offer.type == OfferType.sell;

  Color get _typeColor =>
      _isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

  Color _statusColor(String s) => switch (s.toUpperCase()) {
    'ACTIVE'    => const Color(0xFF16A34A),
    'PAUSED'    => const Color(0xFFD97706),
    'COMPLETED' => const Color(0xFF2563EB),
    'CANCELLED' => const Color(0xFFDC2626),
    _           => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final c         = widget.c;
    final offer     = widget.offer;
    final typeColor = _typeColor;
    final statusText = offer.status?.name.toUpperCase() ?? 'UNKNOWN';
    final enabled   = widget.enabled;

    return GestureDetector(
      onTapDown:   enabled ? (_) => _pressCtrl.forward()                  : null,
      onTapUp:     enabled ? (_) { _pressCtrl.reverse(); widget.onTap(); } : null,
      onTapCancel: enabled ? () => _pressCtrl.reverse()                   : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.48,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 3px top accent bar
                  Container(height: 3, color: typeColor),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                        const SizedBox(height: 13),
                        _SolidDivider(c: c),
                        const SizedBox(height: 13),

                        _PriceRow(
                          c: c,
                          offer: offer,
                          typeColor: typeColor,
                          marketPrice: widget.marketPrice,
                          priceLoading: widget.priceLoading,
                          shimmerAnim: widget.shimmerAnim,
                        ),

                        const SizedBox(height: 12),

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
        // Direction icon badge
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Icon(
            isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 17,
            color: typeColor,
          ),
        ),
        const SizedBox(width: 11),

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
              : Text('Unknown merchant',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ),

        const SizedBox(width: 10),

        // Status pill
        _Pill(
          label: statusText,
          textColor: Colors.white,
          bg: statusColor,
          border: statusColor,
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
    MerchantTier.basic: 'Basic', MerchantTier.standard: 'Standard',
    MerchantTier.premium: 'Premium', MerchantTier.vip: 'VIP',
    MerchantTier.unknown: 'Basic',
  };
  static const _tierColor = {
    MerchantTier.vip:      Color(0xFFB45309),
    MerchantTier.premium:  Color(0xFF7C3AED),
    MerchantTier.standard: Color(0xFF2563EB),
    MerchantTier.basic:    Color(0xFF6B7280),
    MerchantTier.unknown:  Color(0xFF6B7280),
  };
  static const _availColor = {
    SellerAvailability.available:   Color(0xFF16A34A),
    SellerAvailability.unavailable: Color(0xFF6B7280),
    SellerAvailability.onBreak:     Color(0xFFD97706),
    SellerAvailability.unknown:     Color(0xFF6B7280),
  };
  static const _availLabel = {
    SellerAvailability.available:   'Online',
    SellerAvailability.unavailable: 'Offline',
    SellerAvailability.onBreak:     'On Break',
    SellerAvailability.unknown:     'Offline',
  };

  @override
  Widget build(BuildContext context) {
    final tierColor  = _tierColor[profile.tier]!;
    final availColor = _availColor[profile.availability]!;
    final availText  = _availLabel[profile.availability]!;

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
                  fontSize: 13.5,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _tierLabel[profile.tier]!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Location · Rating · Availability
        Row(
          children: [
            if (profile.country != null && profile.country!.isNotEmpty) ...[
              Icon(Icons.place_outlined, size: 11, color: c.textSecondary),
              const SizedBox(width: 2),
              Text(
                profile.country!,
                style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              _MetaDot(c: c),
            ],
            if (loadingReviews)
              _SkimBox(c: c, w: 42, h: 10, r: 3, anim: shimmerAnim)
            else if (averageRating != null) ...[
              Icon(Icons.star_rounded, size: 11, color: const Color(0xFFD97706)),
              const SizedBox(width: 2),
              Text(
                averageRating!.toStringAsFixed(1),
                style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              if (reviewCount > 0) ...[
                const SizedBox(width: 1),
                Text(
                  '($reviewCount)',
                  style: TextStyle(color: c.textSecondary, fontSize: 10),
                ),
              ],
              _MetaDot(c: c),
            ],
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: availColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              availText,
              style: TextStyle(color: availColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class _MerchantSkeleton extends StatelessWidget {
  const _MerchantSkeleton({required this.c, required this.shimmerAnim});
  final AppColor c;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SkimBox(c: c, w: 110, h: 13, r: 4, anim: shimmerAnim),
      const SizedBox(height: 6),
      _SkimBox(c: c, w: 72,  h: 10, r: 3, anim: shimmerAnim),
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
    final margin   = _marginBadge;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pair + margin badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${offer.asset} / ${offer.fiatCurrency.toUpperCase()}',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  if (margin != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        margin,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 5),

              // Limits
              Row(
                children: [
                  _LimitText(c: c, prefix: 'Min', value: offer.minAmount),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(color: c.border, shape: BoxShape.circle),
                    ),
                  ),
                  _LimitText(c: c, prefix: 'Max', value: offer.maxAmount),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Live price chip
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: hasPrice ? typeColor : c.background,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: hasPrice ? typeColor : c.border),
          ),
          child: hasPrice
              ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                marketPrice!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: -0.3,
                  fontFeatures: [FontFeature.tabularFigures()],
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
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _LimitText extends StatelessWidget {
  const _LimitText({required this.c, required this.prefix, required this.value});
  final AppColor c;
  final String prefix;
  final dynamic value;

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(children: [
      TextSpan(
        text: '$prefix ',
        style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
      ),
      TextSpan(
        text: value != null ? '$value' : '—',
        style: TextStyle(
          color: value != null ? c.textPrimary : c.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ]),
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
    final successRateLabel = rate == null ? null : '${rate.toStringAsFixed(1)}%';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Type pill — solid fill
        _Pill(
          label: isBuy ? 'BUY' : 'SELL',
          textColor: Colors.white,
          bg: typeColor,
          border: typeColor,
          fontSize: 10.5,
          weight: FontWeight.w800,
        ),
        if (successRateLabel != null) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 10.5, color: c.success),
                const SizedBox(width: 4),
                Text(
                  '$successRateLabel success',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (offer.availableQty != null) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_outlined, size: 10.5, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${offer.availableQty} avail.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        const Spacer(),

        if (loadingPaymentMethods)
          _SkimBox(c: c, w: 88, h: 11, r: 4, anim: shimmerAnim)
        else if (effectiveIds.isNotEmpty)
          _PaymentRow(
            c: c,
            methods: effectiveIds
                .map((id) => paymentMethodsMap[id])
                .whereType<PaymentMethodModel>()
                .toList(),
            fallbackNames: paymentNames(effectiveIds),
          ),

        const SizedBox(width: 10),

        // Chevron
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Icon(Icons.chevron_right_rounded, size: 16, color: c.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.c, required this.methods, required this.fallbackNames});
  final AppColor c;
  final List<PaymentMethodModel> methods;
  final String fallbackNames;

  @override
  Widget build(BuildContext context) {
    final hasLogos = methods.any((m) => m.logo != null && m.logo!.isNotEmpty);

    if (!hasLogos) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 11, color: c.textSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              fallbackNames,
              style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    const maxLogos = 3;
    final shown = methods.take(maxLogos).toList();
    final extra = methods.length - maxLogos;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown.length * 16.0 + 8,
          height: 24,
          child: Stack(
            children: shown.asMap().entries.map((e) => Positioned(
              left: e.key * 16.0,
              child: _LogoAvatar(method: e.value, c: c, size: 24),
            )).toList(),
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 5),
          Text(
            '+$extra',
            style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ] else if (methods.length == 1) ...[
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              methods.first.name,
              style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({required this.method, required this.c, this.size = 24});
  final PaymentMethodModel method;
  final AppColor c;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = method.logo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.10),
        child: logo != null && logo.isNotEmpty
            ? Image.network(
          logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallback(),
        )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Center(
    child: Text(
      method.name.isNotEmpty ? method.name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w700,
        color: c.textSecondary,
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
    required this.border,
    required this.fontSize,
    required this.weight,
  });
  final String label;
  final Color textColor, bg, border;
  final double fontSize;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: 0.3,
      ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final skeletonColor = isLight
            ? Color.lerp(const Color(0xFFE5E7EB), const Color(0xFFD1D5DB), anim.value)!
            : Color.lerp(const Color(0xFF2A2A2A), const Color(0xFF3A3A3A), anim.value)!;
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: skeletonColor,
            borderRadius: BorderRadius.circular(r),
          ),
        );
      },
    );
  }
}
