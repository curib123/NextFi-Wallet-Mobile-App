import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/core/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/core/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/services/offers/models/offers_models.dart';
import 'package:next_fi/core/services/offer_payment_method/offer_payment_method_core_service.dart';
import 'package:next_fi/core/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/core/services/reviews/reviews_core_service.dart';

abstract class _T {
  static const assetName = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const assetPair = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.2,
  );

  static const price = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const merchantName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const micro = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static const button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    height: 1.0,
  );

  static const rating = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const available = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
  );
}

class PublicOfferTile extends StatefulWidget {
  const PublicOfferTile({
    super.key,
    required this.c,
    required this.offer,
    required this.marketPrice,
    required this.onTap,
    required this.shimmerAnim,
    required this.assetVm,
    this.priceLoading = false,
    this.enabled = true,
  });

  final AppColor c;
  final OfferModel offer;
  final String? marketPrice;
  final VoidCallback onTap;
  final Animation<double> shimmerAnim;
  final AssetVM assetVm;
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
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
    _loadData();
  }

  @override
  void didUpdateWidget(covariant PublicOfferTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.id != widget.offer.id) {
      setState(() {
        _loadingMerchant = true;
        _loadingReviews = true;
      });
      _loadData();
    }
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadMerchantProfile();
    await Future.wait([_loadReviews(), _loadPaymentMethods()]);
  }

  List<String> _resolveSellerIds(
    OfferModel offer, {
    MerchantProfileModel? profile,
  }) {
    final ids = <String>[];
    void add(dynamic raw) {
      final v = raw?.toString().trim() ?? '';
      if (v.isEmpty || ids.contains(v)) return;
      ids.add(v);
    }

    final seller = offer.seller;
    if (seller != null) {
      add(seller['userId']);
      add(seller['user_id']);
      add(seller['id']);
    }
    add(offer.sellerId);
    add(profile?.userId);
    add(profile?.id);
    return ids;
  }

  Future<void> _loadMerchantProfile() async {
    final ids = _resolveSellerIds(widget.offer);
    if (ids.isEmpty) {
      if (mounted) setState(() => _loadingMerchant = false);
      return;
    }
    MerchantProfileModel? profile;
    for (final id in ids) {
      try {
        final candidate = await _merchantCore.getPublic(id);
        if (candidate != null) {
          profile = candidate;
          break;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _merchantProfile = profile;
        if (profile?.avgRating != null) _averageRating = profile!.avgRating;
        _loadingMerchant = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    final offerId = widget.offer.id.trim();
    if (offerId.isEmpty) {
      if (mounted) setState(() => _loadingReviews = false);
      return;
    }
    try {
      final summary = await _reviewsCore.getOfferRatingSummary(offerId);
      if (mounted) {
        setState(() {
          _averageRating = summary.averageRating ?? _merchantProfile?.avgRating;
          _reviewCount = summary.reviewCount;
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _averageRating = _merchantProfile?.avgRating;
          _loadingReviews = false;
        });
      }
    }
  }

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

  bool get _isBuy => widget.offer.type == OfferType.sell;
  Color get _typeColor => _isBuy ? widget.c.success : widget.c.error;

  String _formatCount(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k'
      : '$n';

  List<PaymentMethodModel> get _resolvedMethods {
    final ids = _paymentMethodsMap.isNotEmpty
        ? _paymentMethodsMap.keys.toList()
        : widget.offer.paymentMethodIds;
    return ids
        .map((id) => _paymentMethodsMap[id])
        .whereType<PaymentMethodModel>()
        .toList();
  }

  String _fallbackPaymentNames() {
    final ids = _paymentMethodsMap.isNotEmpty
        ? _paymentMethodsMap.keys.toList()
        : widget.offer.paymentMethodIds;
    return ids
        .map((id) => _paymentMethodsMap[id]?.name ?? id)
        .take(2)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final offer = widget.offer;
    final typeColor = _typeColor;
    final isBuy = _isBuy;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _pressCtrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _pressCtrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => _pressCtrl.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.45,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: c.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMerchantRow(c),
                  const SizedBox(height: 12),
                  _Divider(c: c),
                  const SizedBox(height: 12),
                  _buildAssetPriceRow(c, offer, typeColor),
                  const SizedBox(height: 12),
                  _Divider(c: c),
                  const SizedBox(height: 12),
                  _buildFooter(c, offer, typeColor, isBuy),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantRow(AppColor c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: _loadingMerchant
              ? _ShimBox(c: c, w: 44, h: 44, r: 22, anim: widget.shimmerAnim)
              : _Avatar(c: c, profile: _merchantProfile),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _loadingMerchant
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShimBox(
                      c: c,
                      w: 120,
                      h: 12,
                      r: 4,
                      anim: widget.shimmerAnim,
                    ),
                    const SizedBox(height: 6),
                    _ShimBox(
                      c: c,
                      w: 80,
                      h: 10,
                      r: 3,
                      anim: widget.shimmerAnim,
                    ),
                  ],
                )
              : _merchantProfile != null
              ? _MerchantInfo(
                  c: c,
                  profile: _merchantProfile!,
                  merchantType: _merchantProfile!.type,
                  averageRating: _averageRating,
                  reviewCount: _reviewCount,
                  loadingReviews: _loadingReviews,
                  shimmerAnim: widget.shimmerAnim,
                  formatCount: _formatCount,
                )
              : Text(
                  'Unknown merchant',
                  style: _T.caption.copyWith(color: c.textSecondary),
                ),
        ),
      ],
    );
  }

  Widget _buildAssetPriceRow(AppColor c, OfferModel offer, Color typeColor) {
    final logoUrl = widget.assetVm.logoFor(offer.asset);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: _AssetLogo(c: c, logoUrl: logoUrl),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      offer.asset,
                      style: _T.assetName.copyWith(color: c.textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ ${offer.fiatCurrency.toUpperCase()}',
                    style: _T.assetPair.copyWith(color: c.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  _SmallChip(
                    c: c,
                    label:
                        '${offer.limitType == OfferLimitType.asset ? offer.asset : offer.fiatCurrency} limits',
                  ),
                  if (offer.minAmount != null || offer.maxAmount != null)
                    _SmallChip(
                      c: c,
                      label:
                          'Min: ${offer.minAmount ?? "-"} | Max: ${offer.maxAmount ?? "-"}',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (widget.priceLoading)
          _ShimBox(c: c, w: 76, h: 36, r: 10, anim: widget.shimmerAnim)
        else if (widget.marketPrice != null)
          _PricePill(c: c, price: widget.marketPrice!, color: typeColor)
        else
          Text('-', style: _T.price.copyWith(color: c.textSecondary)),
      ],
    );
  }

  Widget _buildFooter(
    AppColor c,
    OfferModel offer,
    Color typeColor,
    bool isBuy,
  ) {
    final methods = _resolvedMethods;
    final fallback = _fallbackPaymentNames();
    final rate = offer.successRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (offer.availableQty != null) ...[
              Icon(Icons.layers_outlined, size: 12, color: c.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Watcher sync: ${offer.availableQty} ${offer.asset}',
                  style: _T.available.copyWith(color: c.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (_loadingPaymentMethods)
              _ShimBox(c: c, w: 72, h: 11, r: 3, anim: widget.shimmerAnim)
            else if (methods.isNotEmpty)
              Expanded(
                child: _PaymentMethodChip(c: c, method: methods.first),
              )
            else if (fallback.isNotEmpty)
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 12,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        fallback,
                        style: _T.caption.copyWith(color: c.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _ActionButton(
                c: c,
                label: isBuy ? 'BUY' : 'SELL',
                color: typeColor,
              ),
            ),
            if (rate != null) ...[
              const SizedBox(width: 8),
              _ReliabilityChip(c: c, rate: rate),
            ],
          ],
        ),

        if (!_loadingPaymentMethods && methods.length > 1) ...[
          const SizedBox(height: 8),
          _ExtraPaymentRow(c: c, methods: methods),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.c, required this.profile});
  final AppColor c;
  final MerchantProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final initials = profile != null && profile!.displayName.isNotEmpty
        ? profile!.displayName
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
        : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: c.background,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _MerchantInfo extends StatelessWidget {
  const _MerchantInfo({
    required this.c,
    required this.profile,
    required this.merchantType,
    required this.averageRating,
    required this.reviewCount,
    required this.loadingReviews,
    required this.shimmerAnim,
    required this.formatCount,
  });

  final AppColor c;
  final MerchantProfileModel profile;
  final MerchantType merchantType;
  final double? averageRating;
  final int reviewCount;
  final bool loadingReviews;
  final Animation<double> shimmerAnim;
  final String Function(int) formatCount;

  static const _tierLabel = {
    MerchantTier.bronze: 'Bronze',
    MerchantTier.silver: 'Silver',
    MerchantTier.gold: 'Gold',
    MerchantTier.platinum: 'Platinum',
    MerchantTier.diamond: 'Diamond',
  };

  Map<MerchantTier, Color> _tierBg(AppColor c) => {
    MerchantTier.bronze: const Color(0xFFCD7F32).withValues(alpha: 0.14),
    MerchantTier.silver: c.textSecondary.withValues(alpha: 0.11),
    MerchantTier.gold: c.warning.withValues(alpha: 0.14),
    MerchantTier.platinum: c.info.withValues(alpha: 0.11),
    MerchantTier.diamond: c.info.withValues(alpha: 0.14),
  };

  Map<MerchantTier, Color> _tierFg(AppColor c) => {
    MerchantTier.bronze: const Color(0xFFCD7F32),
    MerchantTier.silver: c.textSecondary,
    MerchantTier.gold: c.warning,
    MerchantTier.platinum: c.info,
    MerchantTier.diamond: c.info,
  };

  @override
  Widget build(BuildContext context) {
    final tierBg =
        _tierBg(c)[profile.tier] ?? c.textSecondary.withValues(alpha: 0.11);
    final tierFg = _tierFg(c)[profile.tier] ?? c.textSecondary;
    final tierText = _tierLabel[profile.tier] ?? 'Unknown';

    final isOnline = profile.availability == SellerAvailability.available;
    final availColor = isOnline ? c.success : c.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                profile.displayName,
                style: _T.merchantName.copyWith(color: c.textPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            _TierBadge(c: c, bg: tierBg, fg: tierFg, label: tierText),
            const SizedBox(width: 5),
            _MerchantTypeBadge(c: c, type: merchantType),
          ],
        ),

        const SizedBox(height: 4),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: availColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),

            if (profile.country != null && profile.country!.isNotEmpty) ...[
              Flexible(
                flex: 2,
                child: Text(
                  profile.country!,
                  style: _T.caption.copyWith(color: c.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              _Dot(c: c),
            ],

            if (loadingReviews)
              Flexible(
                flex: 1,
                child: _ShimBox(c: c, w: 56, h: 10, r: 3, anim: shimmerAnim),
              )
            else ...[
              Icon(Icons.star_rounded, size: 11, color: c.warning),
              const SizedBox(width: 2),
              Text(
                averageRating == null
                    ? '--'
                    : averageRating!.toStringAsFixed(1),
                style: _T.rating.copyWith(color: c.textPrimary),
              ),
              const SizedBox(width: 3),
              Flexible(
                flex: 1,
                child: Text(
                  '(${formatCount(reviewCount)} trades)',
                  style: _T.caption.copyWith(color: c.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.c,
    required this.bg,
    required this.fg,
    required this.label,
  });
  final AppColor c;
  final Color bg;
  final Color fg;
  final String label;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 100),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 10, color: fg),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: _T.micro.copyWith(color: fg),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({required this.c, required this.logoUrl});
  final AppColor c;
  final String logoUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.background,
      border: Border.all(color: c.border),
    ),
    child: ClipOval(
      child: Image.network(
        logoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.currency_bitcoin, size: 16, color: c.textSecondary),
      ),
    ),
  );
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.c, required this.price, required this.color});
  final AppColor c;
  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 140),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      price,
      style: _T.price.copyWith(color: c.onPrimary),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.c,
    required this.label,
    required this.color,
  });
  final AppColor c;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Text(label, style: _T.button.copyWith(color: c.onPrimary)),
  );
}

class _ReliabilityChip extends StatelessWidget {
  const _ReliabilityChip({required this.c, required this.rate});
  final AppColor c;
  final double rate;

  String get _label {
    if (rate >= 100) return 'Perfect';
    if (rate >= 95) return 'Excellent';
    if (rate >= 80) return 'High';
    if (rate >= 60) return 'Medium';
    if (rate >= 40) return 'Low';
    return 'Poor';
  }

  Color _color(AppColor c) {
    if (rate >= 80) return c.success;
    if (rate >= 40) return c.warning;
    return c.error;
  }

  @override
  Widget build(BuildContext context) {
    final col = _color(c);
    final pct = rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'TRUST',
            style: _T.micro.copyWith(
              color: c.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$pct%',
            style: _T.rating.copyWith(
              color: col,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _label,
            style: _T.micro.copyWith(color: col, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({required this.c, required this.method});
  final AppColor c;
  final PaymentMethodModel method;

  @override
  Widget build(BuildContext context) {
    final logo = method.logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: c.border),
            ),
            child: logo != null && logo.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 11,
                        color: c.textSecondary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 11,
                    color: c.textSecondary,
                  ),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            method.name,
            style: _T.caption.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _ExtraPaymentRow extends StatelessWidget {
  const _ExtraPaymentRow({required this.c, required this.methods});
  final AppColor c;
  final List<PaymentMethodModel> methods;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: methods
        .skip(1)
        .take(3)
        .map((m) => _PaymentMethodChip(c: c, method: m))
        .toList(),
  );
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.c, required this.label});
  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 180),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: c.border),
    ),
    child: Text(
      label,
      style: _T.micro.copyWith(
        color: c.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  );
}

class _MerchantTypeBadge extends StatelessWidget {
  const _MerchantTypeBadge({required this.c, required this.type});
  final AppColor c;
  final MerchantType type;

  _BadgeStyle _resolve(AppColor c) {
    final name = type.name.toLowerCase();
    if (name.contains('business') || name.contains('corporate')) {
      return _BadgeStyle(
        label: 'Business',
        icon: Icons.business_center_outlined,
        bg: c.info,
        fg: c.onPrimary,
      );
    }
    return _BadgeStyle(
      label: 'Individual',
      icon: Icons.person_outline_rounded,
      bg: c.primaryDark,
      fg: c.onPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _resolve(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 9.5, color: s.fg),
          const SizedBox(width: 3),
          Text(
            s.label.toUpperCase(),
            style: _T.micro.copyWith(
              color: s.fg,
              fontSize: 8.6,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
}

class _Divider extends StatelessWidget {
  const _Divider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: c.border.withValues(alpha: 0.5));
}

class _Dot extends StatelessWidget {
  const _Dot({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text('|', style: _T.caption.copyWith(color: c.textSecondary)),
  );
}

class _ShimBox extends StatelessWidget {
  const _ShimBox({
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
        ? c.border.withValues(alpha: 0.5)
        : c.background.withValues(alpha: 0.98);
    final highlight = isDark
        ? c.textPrimary.withValues(alpha: 0.16)
        : c.onPrimary.withValues(alpha: 0.65);
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
                final band = w * 0.5;
                final travel = w + band * 2;
                final left = travel * anim.value - band;
                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: band,
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
