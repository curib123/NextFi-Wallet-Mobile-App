import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offer_payment_method/offer_payment_method_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';
import 'package:next_fi/common/components/modal/public_offer_reviews_modal.dart';
import 'package:next_fi/features/offers/view/widgets/offer_details_widgets.dart';

class OfferDetailsModal extends StatefulWidget {
  const OfferDetailsModal({
    super.key,
    required this.offer,
    required this.marketPrice,
    required this.onTradeNow,
  });

  final OfferModel offer;
  final String? marketPrice;
  final VoidCallback onTradeNow;

  @override
  State<OfferDetailsModal> createState() => _OfferDetailsModalState();
}

class _OfferDetailsModalState extends State<OfferDetailsModal>
    with TickerProviderStateMixin {
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

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    );
    _fadeController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadMerchantProfile();
    await Future.wait([
      _loadReviews(),
      _loadPaymentMethods(),
    ]);
  }

  List<String> _resolveSellerIds({MerchantProfileModel? profile}) {
    final ids = <String>[];
    void add(dynamic raw) {
      final v = raw?.toString().trim() ?? '';
      if (v.isEmpty) return;
      if (!ids.contains(v)) ids.add(v);
    }

    final seller = widget.offer.seller;
    if (seller != null) {
      add(seller['userId']);
      add(seller['user_id']);
      add(seller['id']);
    }
    add(widget.offer.sellerId);
    add(profile?.userId);
    add(profile?.id);
    return ids;
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await _offerPaymentCore.getPaymentMethodsForOffer(
        widget.offer.id,
      );
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

  List<String> get _effectivePaymentMethodIds => _paymentMethodsMap.isNotEmpty
      ? _paymentMethodsMap.keys.toList()
      : widget.offer.paymentMethodIds;

  String _getPaymentMethodNames(List<String> ids) =>
      ids.map((id) => _paymentMethodsMap[id]?.name ?? id).join(' · ');

  Future<void> _loadMerchantProfile() async {
    final ids = _resolveSellerIds();
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
      } catch (_) {
        // try next candidate
      }
    }
    if (mounted) {
      setState(() {
        _merchantProfile = profile;
        if (profile?.avgRating != null) {
          _averageRating = profile!.avgRating;
        }
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
          _reviewCount = summary.reviewCount;
          _averageRating = summary.averageRating ?? _merchantProfile?.avgRating;
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reviewCount = 0;
          _averageRating = _merchantProfile?.avgRating;
          _loadingReviews = false;
        });
      }
    }
  }

  Future<void> _openAllReviewsSheet() async {
    final c = AppColor.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => PublicOfferReviewsModal(
        offerId: widget.offer.id,
        c: c,
        averageRating: _averageRating,
        totalCount: _reviewCount,
      ),
    );
  }

  // ─── Color / label helpers ──────────────────────────────────────────────────

  bool get _isBuy => widget.offer.type == OfferType.sell;

  Color _typeColor(AppColor c) => _isBuy ? c.success : c.error;

  Color _statusColor(String status, AppColor c) =>
      switch (status.toUpperCase()) {
        'ACTIVE' => c.success,
        'PAUSED' => c.warning,
        'COMPLETED' => c.info,
        'CANCELLED' => c.error,
        _ => c.accent,
      };

  // ── Tier ──────────────────────────────────────────────────────────────────

  static String _tierLabel(MerchantTier t) => const {
    MerchantTier.bronze: 'Bronze',
    MerchantTier.silver: 'Silver',
    MerchantTier.gold: 'Gold',
    MerchantTier.platinum: 'Platinum',
    MerchantTier.diamond: 'Diamond',
  }[t] ?? 'Unknown';                                          // ← was [t]!

  static Color _tierColor(MerchantTier t, AppColor c) => {
    MerchantTier.diamond: c.info,
    MerchantTier.platinum: c.textSecondary,
    MerchantTier.gold: c.warning,
    MerchantTier.silver: c.accent,
    MerchantTier.bronze: c.error,
  }[t] ?? c.accent;                                          // ← was [t]!

  static IconData _tierIcon(MerchantTier t) => const {
    MerchantTier.bronze: Icons.shield_outlined,
    MerchantTier.silver: Icons.workspace_premium_outlined,
    MerchantTier.gold: Icons.emoji_events_outlined,
    MerchantTier.platinum: Icons.military_tech_outlined,
    MerchantTier.diamond: Icons.diamond_outlined,
  }[t] ?? Icons.shield_outlined;                             // ← was [t]!

  // ── Merchant Type ─────────────────────────────────────────────────────────

  static String _typeLabel(MerchantType t) => const {
    MerchantType.individual: 'INDIVIDUAL',
    MerchantType.business: 'BUSINESS',
  }[t] ?? 'UNKNOWN';                                         // ← was [t]!

  static IconData _typeIcon(MerchantType t) => const {
    MerchantType.individual: Icons.person_outline_rounded,
    MerchantType.business: Icons.store_outlined,
  }[t] ?? Icons.person_outline_rounded;                      // ← was [t]!

  // ── Availability ──────────────────────────────────────────────────────────

  static String _availLabel(SellerAvailability a) => const {
    SellerAvailability.available: 'Online',
    SellerAvailability.unavailable: 'Offline',
    SellerAvailability.onBreak: 'On Break',
    SellerAvailability.unknown: 'Offline',
  }[a] ?? 'Offline';                                         // ← was [a]! (safe but consistent)

  static Color _availColor(SellerAvailability a, AppColor c) => {
    SellerAvailability.available: c.success,
    SellerAvailability.unavailable: c.accent,
    SellerAvailability.onBreak: c.warning,
    SellerAvailability.unknown: c.accent,
  }[a] ?? c.accent;                                          // ← was [a]! (safe but consistent)

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final offer = widget.offer;
    final typeColor = _typeColor(c);
    final statusText = offer.status?.name.toUpperCase() ?? 'UNKNOWN';
    final hasLivePrice = widget.marketPrice != null;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroHeader(
                      c: c,
                      offer: offer,
                      isBuy: _isBuy,
                      typeColor: typeColor,
                      statusText: statusText,
                      statusColor: _statusColor(statusText, c),
                      hasLivePrice: hasLivePrice,
                      marketPrice: widget.marketPrice,
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingMerchant)
                            _MerchantCardSkeleton(
                              c: c,
                              shimmerAnim: _shimmerAnim,
                            )
                          else if (_merchantProfile != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                MerchantInfoSection(
                                  c: c,
                                  profile: _merchantProfile!,
                                  getTierLabel: _tierLabel,
                                  getTierColor: (t) => _tierColor(t, c),
                                  getTierIcon: _tierIcon,
                                  getTypeLabel: _typeLabel,
                                  getTypeIcon: _typeIcon,
                                  getAvailabilityLabel: _availLabel,
                                  getAvailabilityColor: (a) => _availColor(a, c),
                                  paymentMethodIds: _effectivePaymentMethodIds
                                      .map(
                                        (id) =>
                                    _paymentMethodsMap[id]?.name ?? id,
                                  )
                                      .toList(),
                                  averageRating: _averageRating,
                                  reviewCount: _reviewCount,
                                  loadingReviews: _loadingReviews,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _loadingReviews
                                        ? null
                                        : _openAllReviewsSheet,
                                    icon: const Icon(
                                      Icons.rate_review_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _loadingReviews
                                          ? 'Loading reviews...'
                                          : 'View offer reviews ($_reviewCount)',
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: c.primary,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 10),
                          _TradeLimitsCard(c: c, offer: offer),
                          const SizedBox(height: 10),
                          _DetailsCard(
                            c: c,
                            offer: offer,
                            shimmerAnim: _shimmerAnim,
                            loadingPaymentMethods: _loadingPaymentMethods,
                            effectivePaymentMethodIds:
                            _effectivePaymentMethodIds,
                            paymentMethodsMap: _paymentMethodsMap,
                            getPaymentMethodNames: _getPaymentMethodNames,
                          ),

                          const SizedBox(height: 14),
                          _TradeButton(
                            typeColor: typeColor,
                            isBuy: _isBuy,
                            onTap: widget.onTradeNow,
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
      ),
    );
  }
}

// ─── Hero Header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.c,
    required this.offer,
    required this.isBuy,
    required this.typeColor,
    required this.statusText,
    required this.statusColor,
    required this.hasLivePrice,
    required this.marketPrice,
  });

  final AppColor c;
  final OfferModel offer;
  final bool isBuy;
  final Color typeColor;
  final String statusText;
  final Color statusColor;
  final bool hasLivePrice;
  final String? marketPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Top row: type pill + status + pair
          Row(
            children: [
              // Type pill — solid fill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBuy
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 14,
                      color: AppColor.of(context).onPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBuy ? 'BUY' : 'SELL',
                      style: TextStyle(
                        color: AppColor.of(context).onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.8,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Status pill — solid fill
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: AppColor.of(context).onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.2,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${offer.asset} / ${offer.fiatCurrency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Live price hero
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (hasLivePrice) ...[
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Text(
                          hasLivePrice ? 'Live Market Price' : 'Price',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasLivePrice ? marketPrice! : 'Not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasLivePrice ? c.textPrimary : c.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.9,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Market rate badge
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 14, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      'Market rate',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Trade Limits Card ────────────────────────────────────────────────────────

class _TradeLimitsCard extends StatelessWidget {
  const _TradeLimitsCard({required this.c, required this.offer});
  final AppColor c;
  final OfferModel offer;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            c: c,
            icon: Icons.stacked_bar_chart_rounded,
            label: 'Trade Limits',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LimitBox(
                  c: c,
                  label: 'Min',
                  value: offer.minAmount?.toString() ?? '—',
                  icon: Icons.south_rounded,
                  color: c.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LimitBox(
                  c: c,
                  label: 'Max',
                  value: offer.maxAmount?.toString() ?? '—',
                  icon: Icons.north_rounded,
                  color: c.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LimitBox(
                  c: c,
                  label: 'Total Qty',
                  value: offer.totalQty?.toString() ?? '—',
                  icon: Icons.layers_outlined,
                  color: c.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LimitBox(
                  c: c,
                  label: 'Available',
                  value: offer.availableQty?.toString() ?? '—',
                  icon: Icons.check_circle_outline_rounded,
                  color: c.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Details Card ─────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.c,
    required this.offer,
    required this.shimmerAnim,
    required this.loadingPaymentMethods,
    required this.effectivePaymentMethodIds,
    required this.paymentMethodsMap,
    required this.getPaymentMethodNames,
  });

  final AppColor c;
  final OfferModel offer;
  final Animation<double> shimmerAnim;
  final bool loadingPaymentMethods;
  final List<String> effectivePaymentMethodIds;
  final Map<String, PaymentMethodModel> paymentMethodsMap;
  final String Function(List<String>) getPaymentMethodNames;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            c: c,
            icon: Icons.info_outline_rounded,
            label: 'Details',
          ),
          const SizedBox(height: 10),
          _DetailRow(
            c: c,
            label: 'Payment window',
            value: '${offer.paymentWindowMinutes ?? '—'} min',
          ),
          _DetailRow(
            c: c,
            label: 'Visible',
            value: offer.isVisible ? 'Yes' : 'No',
          ),
          _DetailRow(
            c: c,
            label: 'Success rate',
            value: offer.successRate != null
                ? '${offer.successRate!.toStringAsFixed(1)}%'
                : '—',
          ),
          if (loadingPaymentMethods)
            _LoadingDetailMethodsRow(c: c, shimmerAnim: shimmerAnim)
          else if (effectivePaymentMethodIds.isEmpty)
            _DetailRow(c: c, label: 'Payment methods', value: '—', isLast: true)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  child: Text(
                    'Payment methods',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: effectivePaymentMethodIds.map((id) {
                      final method = paymentMethodsMap[id];
                      if (method == null) return const SizedBox.shrink();
                      return _PaymentMethodChip(c: c, method: method);
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Trade Button ─────────────────────────────────────────────────────────────

class _TradeButton extends StatefulWidget {
  const _TradeButton({
    required this.typeColor,
    required this.isBuy,
    required this.onTap,
  });
  final Color typeColor;
  final bool isBuy;
  final VoidCallback onTap;

  @override
  State<_TradeButton> createState() => _TradeButtonState();
}

class _TradeButtonState extends State<_TradeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.typeColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isBuy
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: AppColor.of(context).onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trade Now',
                  style: TextStyle(
                    color: AppColor.of(context).onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
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

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.c, required this.child});
  final AppColor c;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.border),
    ),
    child: child,
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: c.border);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.c,
    required this.icon,
    required this.label,
  });
  final AppColor c;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: c.textPrimary),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    ],
  );
}

class _LimitBox extends StatelessWidget {
  const _LimitBox({
    required this.c,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final AppColor c;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: AppColor.of(context).onPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.c,
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final AppColor c;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Payment Method Chip ──────────────────────────────────────────────────────

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({required this.c, required this.method});
  final AppColor c;
  final PaymentMethodModel method;

  @override
  Widget build(BuildContext context) {
    final logo = method.logo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logo != null && logo.isNotEmpty)
            SizedBox(
              width: 16,
              height: 16,
              child: Image.network(
                logo,
                width: 16,
                height: 16,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _fallbackIcon(c),
              ),
            )
          else
            _fallbackIcon(c),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              method.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 11.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon(AppColor c) =>
      Icon(Icons.account_balance_wallet_outlined, size: 14, color: c.primary);
}

// ─── Skeleton helpers ─────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton({
    required this.c,
    required this.anim,
    required this.height,
    this.width,
  });
  final AppColor c;
  final Animation<double> anim;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? c.border.withValues(alpha: 0.52)
        : c.background.withValues(alpha: 0.98);
    final highlight = isDark
        ? c.textPrimary.withValues(alpha: 0.20)
        : c.onPrimary.withValues(alpha: 0.72);
    final itemWidth = width ?? double.infinity;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: itemWidth,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: base),
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                final safeWidth =
                    width ?? (MediaQuery.sizeOf(context).width * 0.5);
                final bandWidth = safeWidth * 0.52;
                final travel = safeWidth + (bandWidth * 2);
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

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip({required this.anim, this.width = 90});
  final Animation<double> anim;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return _Skeleton(c: c, anim: anim, height: 30, width: width);
  }
}

class _LoadingDetailMethodsRow extends StatelessWidget {
  const _LoadingDetailMethodsRow({required this.c, required this.shimmerAnim});
  final AppColor c;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              'Payment methods',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SkeletonChip(anim: shimmerAnim, width: 96),
                _SkeletonChip(anim: shimmerAnim, width: 104),
                _SkeletonChip(anim: shimmerAnim, width: 86),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantCardSkeleton extends StatelessWidget {
  const _MerchantCardSkeleton({required this.c, required this.shimmerAnim});
  final AppColor c;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Skeleton(c: c, anim: shimmerAnim, height: 44, width: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Skeleton(c: c, anim: shimmerAnim, height: 10, width: 70),
                    const SizedBox(height: 6),
                    _Skeleton(c: c, anim: shimmerAnim, height: 14, width: 160),
                  ],
                ),
              ),
              _Skeleton(c: c, anim: shimmerAnim, height: 24, width: 72),
            ],
          ),
          const SizedBox(height: 14),
          _SectionDivider(c: c),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SkeletonChip(anim: shimmerAnim, width: 90),
              _SkeletonChip(anim: shimmerAnim, width: 84),
              _SkeletonChip(anim: shimmerAnim, width: 94),
            ],
          ),
          const SizedBox(height: 12),
          _Skeleton(c: c, anim: shimmerAnim, height: 11),
          const SizedBox(height: 8),
          _Skeleton(c: c, anim: shimmerAnim, height: 11, width: 230),
          const SizedBox(height: 12),
          _SectionDivider(c: c),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SkeletonChip(anim: shimmerAnim, width: 88),
              _SkeletonChip(anim: shimmerAnim, width: 110),
              _SkeletonChip(anim: shimmerAnim, width: 96),
            ],
          ),
        ],
      ),
    );
  }
}