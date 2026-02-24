import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offer_payment_method/offer_payment_method_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
// BUY  → flat green palette  (#16A34A family)
// SELL → flat red palette    (#DC2626 family)
// No glows. No radial gradients. No color-tinted shadows.

class PublicOfferTile extends StatefulWidget {
  const PublicOfferTile({
    super.key,
    required this.c,
    required this.offer,
    required this.marketPrice,
    required this.onTap,
    this.priceLoading = false,
  });

  final AppColor c;
  final OfferModel offer;
  final String? marketPrice;
  final VoidCallback onTap;
  final bool priceLoading;

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

  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadMerchantProfile(),
      _loadReviews(),
      _loadPaymentMethods(),
    ]);
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods =
      await _offerPaymentCore.getPaymentMethodsForOffer(widget.offer.id);
      if (mounted) {
        setState(() {
          _paymentMethodsMap = {for (var m in methods) m.id: m};
          _loadingPaymentMethods = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPaymentMethods = false);
    }
  }

  String _getPaymentMethodNames(List<String> ids) {
    final names = ids.map((id) {
      final method = _paymentMethodsMap[id];
      return method?.name ?? id;
    }).toList();
    return names.take(3).join(' · ');
  }

  Future<void> _loadMerchantProfile() async {
    final sellerId = widget.offer.sellerId;
    if (sellerId == null || sellerId.isEmpty) {
      if (mounted) setState(() => _loadingMerchant = false);
      return;
    }
    try {
      final profile = await _merchantCore.getPublic(sellerId);
      if (mounted) {
        setState(() {
          _merchantProfile = profile;
          _loadingMerchant = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMerchant = false);
    }
  }

  Future<void> _loadReviews() async {
    final sellerId = widget.offer.sellerId;
    if (sellerId == null || sellerId.isEmpty) {
      if (mounted) setState(() => _loadingReviews = false);
      return;
    }
    try {
      final avgRating = await _reviewsCore.getUserAverageRating(sellerId);
      final count = await _reviewsCore.getUserReviewCount(sellerId);
      if (mounted) {
        setState(() {
          _averageRating = avgRating;
          _reviewCount = count;
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  // User-centric: merchant SELLS = user BUYS
  bool get _isBuy => widget.offer.type == OfferType.sell;

  // Flat, non-glowing type colors
  Color get _typeColor =>
      _isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF16A34A);
      case 'PAUSED':
        return const Color(0xFFD97706);
      case 'COMPLETED':
        return const Color(0xFF2563EB);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final offer = widget.offer;
    final typeColor = _typeColor;
    final statusText = offer.status?.name ?? 'UNKNOWN';

    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.border.withOpacity(isLight ? 0.18 : 0.10),
              width: 1,
            ),
            // Neutral shadow only — no color tinting
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isLight ? 0.06 : 0.18),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isLight ? 0.03 : 0.10),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Thin 2px left-side accent bar (rendered via a Row trick)
                _TypeAccentBar(typeColor: typeColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderRow(
                        c: c,
                        offer: offer,
                        isBuy: _isBuy,
                        typeColor: typeColor,
                        statusText: statusText,
                        statusColor: _statusColor(statusText),
                        merchantProfile: _merchantProfile,
                        loadingMerchant: _loadingMerchant,
                        averageRating: _averageRating,
                        reviewCount: _reviewCount,
                        loadingReviews: _loadingReviews,
                        isLight: isLight,
                      ),
                      const SizedBox(height: 14),
                      _FlatDivider(c: c, isLight: isLight),
                      const SizedBox(height: 12),
                      _PriceAssetRow(
                        c: c,
                        offer: offer,
                        typeColor: typeColor,
                        hasLivePrice: widget.marketPrice != null,
                        marketPrice: widget.marketPrice,
                        priceLoading: widget.priceLoading,
                        isLight: isLight,
                      ),
                      const SizedBox(height: 12),
                      _BottomRow(
                        c: c,
                        offer: offer,
                        typeColor: typeColor,
                        isBuy: _isBuy,
                        loadingPaymentMethods: _loadingPaymentMethods,
                        paymentMethodsMap: _paymentMethodsMap,
                        getPaymentMethodNames: _getPaymentMethodNames,
                        isLight: isLight,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Accent bar ───────────────────────────────────────────────────────────────
// A thin top strip showing the buy/sell color — flat, no gradient, no glow.

class _TypeAccentBar extends StatelessWidget {
  const _TypeAccentBar({required this.typeColor});
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: typeColor,
    );
  }
}

// ─── Header Row ───────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.c,
    required this.offer,
    required this.isBuy,
    required this.typeColor,
    required this.statusText,
    required this.statusColor,
    required this.merchantProfile,
    required this.loadingMerchant,
    required this.averageRating,
    required this.reviewCount,
    required this.loadingReviews,
    required this.isLight,
  });

  final AppColor c;
  final OfferModel offer;
  final bool isBuy;
  final Color typeColor;
  final String statusText;
  final Color statusColor;
  final MerchantProfileModel? merchantProfile;
  final bool loadingMerchant;
  final double? averageRating;
  final int reviewCount;
  final bool loadingReviews;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Flat icon container — no gradient, just a light tint
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: typeColor.withOpacity(isLight ? 0.08 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isBuy
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 18,
            color: typeColor,
          ),
        ),
        const SizedBox(width: 11),

        Expanded(
          child: loadingMerchant
              ? _MerchantSkeleton(c: c)
              : merchantProfile != null
              ? _MerchantInfo(
            c: c,
            profile: merchantProfile!,
            averageRating: averageRating,
            reviewCount: reviewCount,
            loadingReviews: loadingReviews,
          )
              : const SizedBox.shrink(),
        ),

        const SizedBox(width: 10),

        // Status pill — flat
        _FlatPill(
          label: statusText,
          textColor: statusColor,
          bgColor: statusColor.withOpacity(isLight ? 0.08 : 0.12),
          borderColor: statusColor.withOpacity(isLight ? 0.20 : 0.25),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

// ─── Price / Asset Row ────────────────────────────────────────────────────────

class _PriceAssetRow extends StatelessWidget {
  const _PriceAssetRow({
    required this.c,
    required this.offer,
    required this.typeColor,
    required this.hasLivePrice,
    required this.marketPrice,
    required this.priceLoading,
    required this.isLight,
  });

  final AppColor c;
  final OfferModel offer;
  final Color typeColor;
  final bool hasLivePrice;
  final String? marketPrice;
  final bool priceLoading;
  final bool isLight;

  String? get _marginLabel {
    final m = offer.marginPercent;
    if (m == null || m == 0) return null;
    final sign = m > 0 ? '+' : '';
    return '$sign${m.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final marginLabel = _marginLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${offer.asset} / ${offer.fiatCurrency.toUpperCase()}',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                  ),
                  if (marginLabel != null) ...[
                    const SizedBox(width: 7),
                    // Margin badge — flat tint, no border glow
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(isLight ? 0.08 : 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        marginLabel,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                    offer.minAmount != null ? 'Min ${offer.minAmount}' : 'Min —',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '·',
                      style: TextStyle(
                          color: c.textSecondary.withOpacity(0.4),
                          fontSize: 12),
                    ),
                  ),
                  Text(
                    offer.maxAmount != null ? 'Max ${offer.maxAmount}' : 'Max —',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Price chip — flat, no glow on the dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hasLivePrice
                ? typeColor.withOpacity(isLight ? 0.08 : 0.12)
                : c.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasLivePrice
                  ? typeColor.withOpacity(isLight ? 0.22 : 0.28)
                  : c.border.withOpacity(isLight ? 0.16 : 0.12),
              width: 1,
            ),
          ),
          child: hasLivePrice
              ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Solid dot — no boxShadow glow
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                marketPrice!,
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          )
              : (priceLoading
              ? _ShimmerBox(
              c: c,
              width: 72,
              height: 14,
              radius: 4,
              isLight: isLight)
              : Text(
            'No price',
            style: TextStyle(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          )),
        ),
      ],
    );
  }
}

// ─── Bottom Row ───────────────────────────────────────────────────────────────

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.c,
    required this.offer,
    required this.typeColor,
    required this.isBuy,
    required this.loadingPaymentMethods,
    required this.paymentMethodsMap,
    required this.getPaymentMethodNames,
    required this.isLight,
  });

  final AppColor c;
  final OfferModel offer;
  final Color typeColor;
  final bool isBuy;
  final bool loadingPaymentMethods;
  final Map<String, PaymentMethodModel> paymentMethodsMap;
  final String Function(List<String>) getPaymentMethodNames;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final effectiveIds = paymentMethodsMap.isNotEmpty
        ? paymentMethodsMap.keys.toList()
        : offer.paymentMethodIds;

    return Row(
      children: [
        // BUY / SELL pill — flat
        _FlatPill(
          label: isBuy ? 'BUY' : 'SELL',
          textColor: typeColor,
          bgColor: typeColor.withOpacity(isLight ? 0.08 : 0.12),
          borderColor: typeColor.withOpacity(isLight ? 0.20 : 0.25),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),

        if (offer.availableQty != null) ...[
          const SizedBox(width: 8),
          _SmallInfoChip(
            c: c,
            icon: Icons.layers_outlined,
            label: '${offer.availableQty} avail.',
            isLight: isLight,
          ),
        ],

        const Spacer(),

        // Payment methods
        if (loadingPaymentMethods)
          _ShimmerBox(c: c, width: 90, height: 12, radius: 4, isLight: isLight)
        else if (effectiveIds.isNotEmpty)
          _PaymentMethodLogosRow(
            c: c,
            methods: effectiveIds
                .map((id) => paymentMethodsMap[id])
                .whereType<PaymentMethodModel>()
                .toList(),
            fallbackNames: getPaymentMethodNames(effectiveIds),
          ),

        const SizedBox(width: 10),

        // Flat chevron button — no color fill, just a border
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: c.border.withOpacity(isLight ? 0.22 : 0.14),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _FlatDivider extends StatelessWidget {
  const _FlatDivider({required this.c, required this.isLight});
  final AppColor c;
  final bool isLight;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: c.border.withOpacity(isLight ? 0.12 : 0.08),
  );
}

class _FlatPill extends StatelessWidget {
  const _FlatPill({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.fontSize,
    required this.fontWeight,
  });

  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor, width: 1),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: 0.3,
      ),
    ),
  );
}

class _SmallInfoChip extends StatelessWidget {
  const _SmallInfoChip({
    required this.c,
    required this.icon,
    required this.label,
    required this.isLight,
  });
  final AppColor c;
  final IconData icon;
  final String label;
  final bool isLight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: c.border.withOpacity(isLight ? 0.15 : 0.10),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c.textSecondary.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// ─── Payment Method Logo Widgets ──────────────────────────────────────────────

class _PaymentMethodLogosRow extends StatelessWidget {
  const _PaymentMethodLogosRow({
    required this.c,
    required this.methods,
    required this.fallbackNames,
  });

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
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 12,
            color: c.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              fallbackNames,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
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
            children: shown
                .asMap()
                .entries
                .map((e) => Positioned(
              left: e.key * 16.0,
              child: _LogoAvatar(method: e.value, c: c, size: 24),
            ))
                .toList(),
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 5),
          Text(
            '+$extra',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else if (methods.length == 1) ...[
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              methods.first.name,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
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
        border: Border.all(color: c.border.withOpacity(0.18), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.10),
        child: logo != null && logo.isNotEmpty
            ? Image.network(
          logo,
          width: size,
          height: size,
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

// ─── Shimmer ──────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.c,
    required this.width,
    required this.height,
    required this.radius,
    required this.isLight,
  });
  final AppColor c;
  final double width;
  final double height;
  final double radius;
  final bool isLight;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final lo = widget.isLight ? 0.08 : 0.05;
        final hi = widget.isLight ? 0.18 : 0.12;
        final op = lo + (hi - lo) * _anim.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.c.border.withOpacity(op),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

// ─── Merchant Info ────────────────────────────────────────────────────────────

class _MerchantSkeleton extends StatelessWidget {
  const _MerchantSkeleton({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerBox(c: c, width: 110, height: 13, radius: 4, isLight: isLight),
        const SizedBox(height: 5),
        _ShimmerBox(c: c, width: 70, height: 10, radius: 3, isLight: isLight),
      ],
    );
  }
}

class _MerchantInfo extends StatelessWidget {
  const _MerchantInfo({
    required this.c,
    required this.profile,
    this.averageRating,
    this.reviewCount,
    this.loadingReviews = false,
  });

  final AppColor c;
  final MerchantProfileModel profile;
  final double? averageRating;
  final int? reviewCount;
  final bool loadingReviews;

  String _tierLabel(MerchantTier t) => const {
    MerchantTier.basic: 'Basic',
    MerchantTier.standard: 'Standard',
    MerchantTier.premium: 'Premium',
    MerchantTier.vip: 'VIP',
    MerchantTier.unknown: 'Basic',
  }[t]!;

  Color _tierColor(MerchantTier t) => const {
    MerchantTier.vip: Color(0xFFB45309),
    MerchantTier.premium: Color(0xFF7C3AED),
    MerchantTier.standard: Color(0xFF2563EB),
    MerchantTier.basic: Color(0xFF6B7280),
    MerchantTier.unknown: Color(0xFF6B7280),
  }[t]!;

  String _availLabel(SellerAvailability a) => const {
    SellerAvailability.available: 'Online',
    SellerAvailability.unavailable: 'Offline',
    SellerAvailability.onBreak: 'On Break',
    SellerAvailability.unknown: 'Offline',
  }[a]!;

  Color _availColor(SellerAvailability a) => const {
    SellerAvailability.available: Color(0xFF16A34A),
    SellerAvailability.unavailable: Color(0xFF6B7280),
    SellerAvailability.onBreak: Color(0xFFD97706),
    SellerAvailability.unknown: Color(0xFF6B7280),
  }[a]!;

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(profile.tier);
    final availColor = _availColor(profile.availability);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                profile.displayName,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 7),
            // Tier badge — flat, no border, just tinted bg
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(isLight ? 0.08 : 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _tierLabel(profile.tier),
                style: TextStyle(
                  color: tierColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (profile.country != null && profile.country!.isNotEmpty) ...[
              Icon(Icons.place_outlined,
                  size: 11, color: c.textSecondary.withOpacity(0.7)),
              const SizedBox(width: 2),
              Text(
                profile.country!,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (loadingReviews)
              Container(
                width: 46,
                height: 10,
                decoration: BoxDecoration(
                  color: c.border.withOpacity(isLight ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(3),
                ),
              )
            else if (averageRating != null) ...[
              Icon(Icons.star_rounded,
                  size: 11, color: const Color(0xFFD97706)),
              const SizedBox(width: 2),
              Text(
                averageRating!.toStringAsFixed(1),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (reviewCount != null && reviewCount! > 0) ...[
                const SizedBox(width: 2),
                Text(
                  '($reviewCount)',
                  style: TextStyle(
                      color: c.textSecondary.withOpacity(0.7), fontSize: 10),
                ),
              ],
              const SizedBox(width: 10),
            ],
            // Availability dot — solid, no glow/boxShadow
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
              _availLabel(profile.availability),
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
}