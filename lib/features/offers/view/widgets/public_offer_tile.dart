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
    this.priceLoading = false,
  });

  final AppColor c;
  final OfferModel offer;
  final String? marketPrice;
  final VoidCallback onTap;
  /// True while live prices are still being fetched; shows shimmer instead of "No price".
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
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.972).animate(
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

  // ─── Colors ────────────────────────────────────────────────────────────────

  // User-centric: merchant SELLS = user BUYS; merchant BUYS = user SELLS
  bool get _isBuy => widget.offer.type == OfferType.sell;

  // BUY = green (success), SELL = red (error) — from AppColor
  Color get _typeColor => _isBuy ? widget.c.success : widget.c.error;

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF00C48C);
      case 'PAUSED':
        return const Color(0xFFFAA040);
      case 'COMPLETED':
        return const Color(0xFF5B8DEF);
      case 'CANCELLED':
        return const Color(0xFFFF5C72);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final offer = widget.offer;
    final typeColor = _typeColor;
    final statusText = offer.status?.name ?? 'UNKNOWN';
    final hasLivePrice = widget.marketPrice != null;

    // Detect light mode to adjust translucency values
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              // Light mode: more visible border
              color: c.border.withOpacity(isLight ? 0.16 : 0.07),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                // Light mode: tinted shadow is prominent; dark mode: subtle
                color: typeColor.withOpacity(isLight ? 0.10 : 0.06),
                blurRadius: isLight ? 24 : 20,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                // Light mode needs a stronger neutral shadow for depth
                color: Colors.black.withOpacity(isLight ? 0.07 : 0.04),
                blurRadius: isLight ? 14 : 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Soft accent glow top-right — stronger in light mode
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          typeColor.withOpacity(isLight ? 0.14 : 0.10),
                          typeColor.withOpacity(0.0),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Thin colored top strip
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          typeColor.withOpacity(isLight ? 0.85 : 0.7),
                          typeColor.withOpacity(0.08),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
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

                      const SizedBox(height: 16),
                      _Divider(c: c, isLight: isLight),
                      const SizedBox(height: 14),

                      _PriceAssetRow(
                        c: c,
                        offer: offer,
                        typeColor: typeColor,
                        hasLivePrice: hasLivePrice,
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

// ─── Header Row ─────────────────────────────────────────────────────────────

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
        // Avatar / icon — more visible background in light mode
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                typeColor.withOpacity(isLight ? 0.20 : 0.18),
                typeColor.withOpacity(isLight ? 0.10 : 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Icon(
              isBuy
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 20,
              color: typeColor,
            ),
          ),
        ),
        const SizedBox(width: 12),

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

        // Status pill
        _Pill(
          label: statusText,
          textColor: statusColor,
          bgColor: statusColor.withOpacity(isLight ? 0.12 : 0.10),
          borderColor: statusColor.withOpacity(isLight ? 0.30 : 0.18),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

// ─── Price / Asset Row ───────────────────────────────────────────────────────

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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  if (marginLabel != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(isLight ? 0.12 : 0.10),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color:
                                typeColor.withOpacity(isLight ? 0.28 : 0.18)),
                      ),
                      child: Text(
                        marginLabel,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _RangeTag(
                    c: c,
                    label: offer.minAmount != null
                        ? 'Min ${offer.minAmount}'
                        : 'Min —',
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border.withOpacity(isLight ? 0.4 : 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _RangeTag(
                    c: c,
                    label: offer.maxAmount != null
                        ? 'Max ${offer.maxAmount}'
                        : 'Max —',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Price chip — shows effective offer price, shimmer while loading, "No price" as fallback
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: hasLivePrice
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
              : (priceLoading
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
          decoration: BoxDecoration(
            gradient: hasLivePrice
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      typeColor.withOpacity(isLight ? 0.14 : 0.14),
                      typeColor.withOpacity(isLight ? 0.07 : 0.06),
                    ],
                  )
                : LinearGradient(
                    colors: [c.background, c.background],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasLivePrice
                  ? typeColor.withOpacity(isLight ? 0.32 : 0.22)
                  : c.border.withOpacity(isLight ? 0.18 : 0.12),
            ),
          ),
          child: hasLivePrice
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: typeColor
                                .withOpacity(isLight ? 0.45 : 0.5),
                            blurRadius: 5,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      marketPrice!,
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                )
              : (priceLoading
                  ? _ShimmerBox(
                      c: c, width: 72, height: 14, radius: 4, isLight: isLight)
                  : Text(
                      'No price',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        letterSpacing: -0.2,
                      ),
                    )),
        ),
      ],
    );
  }
}

// ─── Bottom Row ──────────────────────────────────────────────────────────────

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
        // BUY / SELL tag
        _Pill(
          label: isBuy ? 'BUY' : 'SELL',
          textColor: typeColor,
          bgColor: typeColor.withOpacity(isLight ? 0.12 : 0.10),
          borderColor: typeColor.withOpacity(isLight ? 0.28 : 0.18),
          fontSize: 11,
          fontWeight: FontWeight.w800,
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

        // Payment method
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

        // Chevron
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: typeColor.withOpacity(isLight ? 0.12 : 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: typeColor,
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.c, required this.isLight});
  final AppColor c;
  final bool isLight;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          c.border.withOpacity(0),
          c.border.withOpacity(isLight ? 0.20 : 0.12),
          c.border.withOpacity(0),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: 0.2,
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: c.border.withOpacity(isLight ? 0.18 : 0.10),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12,
            color: c.textSecondary.withOpacity(isLight ? 0.8 : 0.7)),
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

class _RangeTag extends StatelessWidget {
  const _RangeTag({required this.c, required this.label});
  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: c.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}

// ─── Payment Method Logo Widgets ─────────────────────────────────────────────

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
            size: 13,
            color: c.textSecondary.withOpacity(0.6),
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
        border: Border.all(color: c.border.withOpacity(0.22), width: 1),
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
        final lo = widget.isLight ? 0.10 : 0.06;
        final hi = widget.isLight ? 0.23 : 0.14;
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

// ─── Merchant Info ───────────────────────────────────────────────────────────

class _MerchantSkeleton extends StatelessWidget {
  const _MerchantSkeleton({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerBox(c: c, width: 110, height: 14, radius: 4, isLight: isLight),
        const SizedBox(height: 5),
        _ShimmerBox(c: c, width: 70, height: 11, radius: 3, isLight: isLight),
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
    MerchantTier.vip: Color(0xFFFFAA00),
    MerchantTier.premium: Color(0xFFA855F7),
    MerchantTier.standard: Color(0xFF5B8DEF),
    MerchantTier.basic: Color(0xFF9CA3AF),
    MerchantTier.unknown: Color(0xFF9CA3AF),
  }[t]!;

  String _availLabel(SellerAvailability a) => const {
    SellerAvailability.available: 'Online',
    SellerAvailability.unavailable: 'Offline',
    SellerAvailability.onBreak: 'On Break',
    SellerAvailability.unknown: 'Offline',
  }[a]!;

  Color _availColor(SellerAvailability a) => const {
    SellerAvailability.available: Color(0xFF00C48C),
    SellerAvailability.unavailable: Color(0xFF9CA3AF),
    SellerAvailability.onBreak: Color(0xFFFAA040),
    SellerAvailability.unknown: Color(0xFF9CA3AF),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(isLight ? 0.12 : 0.10),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: tierColor.withOpacity(isLight ? 0.30 : 0.22),
                ),
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
        const SizedBox(height: 5),
        Row(
          children: [
            if (profile.country != null && profile.country!.isNotEmpty) ...[
              Icon(Icons.place_outlined,
                  size: 11, color: c.textSecondary),
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
                height: 11,
                decoration: BoxDecoration(
                  color: c.border.withOpacity(isLight ? 0.18 : 0.13),
                  borderRadius: BorderRadius.circular(3),
                ),
              )
            else if (averageRating != null) ...[
              Icon(Icons.star_rounded,
                  size: 12, color: const Color(0xFFFFAA00)),
              const SizedBox(width: 3),
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
                  style: TextStyle(color: c.textSecondary, fontSize: 10),
                ),
              ],
              const SizedBox(width: 10),
            ],
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: availColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: availColor.withOpacity(isLight ? 0.35 : 0.45),
                    blurRadius: 5,
                  )
                ],
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