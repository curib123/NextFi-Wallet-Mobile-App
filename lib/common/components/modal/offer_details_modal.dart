import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offer_payment_method/offer_payment_method_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/reviews/models/reviews_models.dart';
import 'package:next_fi/services/reviews/reviews_core_service.dart';
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
    with SingleTickerProviderStateMixin {
  final _merchantCore     = MerchantProfileCoreService.I;
  final _reviewsCore      = ReviewsCoreService.I;
  final _offerPaymentCore = OfferPaymentMethodCoreService.I;

  MerchantProfileModel? _merchantProfile;
  bool _loadingMerchant = true;
  List<ReviewModel> _reviews = [];
  double? _averageRating;
  bool _loadingReviews = true;
  Map<String, PaymentMethodModel> _paymentMethodsMap = {};
  bool _loadingPaymentMethods = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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
    _fadeController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
      final methods = await _offerPaymentCore.getPaymentMethodsForOffer(widget.offer.id);
      if (mounted) {
        setState(() {
          _paymentMethodsMap     = {for (var m in methods) m.id: m};
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
    final sellerId = widget.offer.sellerId;
    if (sellerId == null || sellerId.isEmpty) {
      if (mounted) setState(() => _loadingMerchant = false);
      return;
    }
    try {
      final profile = await _merchantCore.getPublic(sellerId);
      if (mounted) setState(() { _merchantProfile = profile; _loadingMerchant = false; });
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
      final reviews   = await _reviewsCore.getUserReviews(userId: sellerId);
      final avgRating = await _reviewsCore.getUserAverageRating(sellerId);
      if (mounted) setState(() {
        _reviews       = reviews;
        _averageRating = avgRating;
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  // ─── Color helpers ──────────────────────────────────────────────────────────

  bool get _isBuy => widget.offer.type == OfferType.sell;

  Color _typeColor(AppColor c) => _isBuy ? c.success : c.error;

  Color _statusColor(String status) => switch (status.toUpperCase()) {
    'ACTIVE'    => const Color(0xFF00C48C),
    'PAUSED'    => const Color(0xFFFAA040),
    'COMPLETED' => const Color(0xFF5B8DEF),
    'CANCELLED' => const Color(0xFFFF5C72),
    _           => const Color(0xFF9CA3AF),
  };

  static String _tierLabel(MerchantTier t) => const {
    MerchantTier.basic:    'Basic',
    MerchantTier.standard: 'Standard',
    MerchantTier.premium:  'Premium',
    MerchantTier.vip:      'VIP',
    MerchantTier.unknown:  'Basic',
  }[t]!;

  static Color _tierColor(MerchantTier t) => const {
    MerchantTier.vip:      Color(0xFFFFAA00),
    MerchantTier.premium:  Color(0xFFA855F7),
    MerchantTier.standard: Color(0xFF5B8DEF),
    MerchantTier.basic:    Color(0xFF9CA3AF),
    MerchantTier.unknown:  Color(0xFF9CA3AF),
  }[t]!;

  static String _availLabel(SellerAvailability a) => const {
    SellerAvailability.available:   'Online',
    SellerAvailability.unavailable: 'Offline',
    SellerAvailability.onBreak:     'On Break',
    SellerAvailability.unknown:     'Offline',
  }[a]!;

  static Color _availColor(SellerAvailability a) => const {
    SellerAvailability.available:   Color(0xFF00C48C),
    SellerAvailability.unavailable: Color(0xFF9CA3AF),
    SellerAvailability.onBreak:     Color(0xFFFAA040),
    SellerAvailability.unknown:     Color(0xFF9CA3AF),
  }[a]!;

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c          = AppColor.of(context);
    final offer      = widget.offer;
    final typeColor  = _typeColor(c);
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
                      statusColor: _statusColor(statusText),
                      hasLivePrice: hasLivePrice,
                      marketPrice: widget.marketPrice,
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingMerchant)
                            _MerchantCardSkeleton(c: c)
                          else if (_merchantProfile != null)
                            MerchantInfoSection(
                              c: c,
                              profile: _merchantProfile!,
                              getTierLabel: _tierLabel,
                              getTierColor: _tierColor,
                              getAvailabilityLabel: _availLabel,
                              getAvailabilityColor: _availColor,
                              paymentMethodIds: _effectivePaymentMethodIds
                                  .map((id) => _paymentMethodsMap[id]?.name ?? id)
                                  .toList(),
                              averageRating: _averageRating,
                              reviewCount: _reviews.length,
                              loadingReviews: _loadingReviews,
                            ),

                          const SizedBox(height: 14),
                          _TradeLimitsCard(c: c, offer: offer),
                          const SizedBox(height: 14),
                          _DetailsCard(
                            c: c,
                            offer: offer,
                            loadingPaymentMethods: _loadingPaymentMethods,
                            effectivePaymentMethodIds: _effectivePaymentMethodIds,
                            paymentMethodsMap: _paymentMethodsMap,
                            getPaymentMethodNames: _getPaymentMethodNames,
                          ),

                          if (_loadingReviews) ...[
                            const SizedBox(height: 14),
                            _ReviewsLoadingCard(c: c),
                          ] else if (_reviews.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _ReviewsCard(c: c, reviews: _reviews, averageRating: _averageRating),
                          ],

                          const SizedBox(height: 20),
                          _TradeButton(typeColor: typeColor, isBuy: _isBuy, onTap: widget.onTradeNow),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
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
              margin: const EdgeInsets.only(bottom: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isBuy ? 'BUY' : 'SELL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status pill — solid fill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.8,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${offer.asset} / ${offer.fiatCurrency}',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.55,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

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
                            fontSize: 12.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasLivePrice ? marketPrice! : 'Not available',
                      style: TextStyle(
                        color: hasLivePrice ? c.textPrimary : c.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        letterSpacing: -1.1,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Market rate badge — solid fill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 15, color: typeColor),
                    const SizedBox(width: 5),
                    Text(
                      'Market rate',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.8,
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
          _SectionLabel(c: c, icon: Icons.stacked_bar_chart_rounded, label: 'Trade Limits'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LimitBox(
                  c: c,
                  label: 'Min',
                  value: offer.minAmount?.toString() ?? '—',
                  icon: Icons.south_rounded,
                  color: const Color(0xFF00C48C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LimitBox(
                  c: c,
                  label: 'Max',
                  value: offer.maxAmount?.toString() ?? '—',
                  icon: Icons.north_rounded,
                  color: const Color(0xFFFF5C72),
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
                  color: const Color(0xFF5B8DEF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LimitBox(
                  c: c,
                  label: 'Available',
                  value: offer.availableQty?.toString() ?? '—',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF00C48C),
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
    required this.loadingPaymentMethods,
    required this.effectivePaymentMethodIds,
    required this.paymentMethodsMap,
    required this.getPaymentMethodNames,
  });

  final AppColor c;
  final OfferModel offer;
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
          _SectionLabel(c: c, icon: Icons.info_outline_rounded, label: 'Details'),
          const SizedBox(height: 14),
          _DetailRow(c: c, label: 'Payment window', value: '${offer.paymentWindowMinutes ?? '—'} min'),
          _DetailRow(c: c, label: 'Visible', value: offer.isVisible ? 'Yes' : 'No'),
          if (loadingPaymentMethods)
            _LoadingDetailMethodsRow(c: c)
          else if (effectivePaymentMethodIds.isEmpty)
            _DetailRow(c: c, label: 'Payment methods', value: '—', isLast: true)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    'Payment methods',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
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

// ─── Reviews Card ─────────────────────────────────────────────────────────────

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({required this.c, required this.reviews, this.averageRating});
  final AppColor c;
  final List<ReviewModel> reviews;
  final double? averageRating;

  static const _amber = Color(0xFFFFAA00);

  @override
  Widget build(BuildContext context) {
    final shown = reviews.take(3).toList();
    return _SectionCard(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review_rounded, size: 16, color: c.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Reviews',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.2,
                ),
              ),
              const Spacer(),
              if (averageRating != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: _amber),
                      const SizedBox(width: 3),
                      Text(
                        averageRating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _amber,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          ...shown.asMap().entries.map((e) => Column(
            children: [
              _ReviewItem(c: c, review: e.value),
              if (e.key < shown.length - 1) const SizedBox(height: 8),
            ],
          )),
        ],
      ),
    );
  }
}

// ─── Trade Button ─────────────────────────────────────────────────────────────

class _TradeButton extends StatefulWidget {
  const _TradeButton({required this.typeColor, required this.isBuy, required this.onTap});
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
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
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
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.typeColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Trade Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
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
  const _SectionLabel({required this.c, required this.icon, required this.label});
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
          fontSize: 14,
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
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
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
    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.c, required this.review});
  final AppColor c;
  final ReviewModel review;

  static const _amber = Color(0xFFFFAA00);

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 30) return '${d.day}/${d.month}/${d.year}';
    if (diff.inDays > 0)  return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: c.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Row(
              children: List.generate(5, (i) => Icon(
                i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: i < review.rating ? _amber : c.border,
              )),
            ),
            const Spacer(),
            if (review.createdAt != null)
              Text(
                _timeAgo(review.createdAt!),
                style: TextStyle(color: c.textSecondary, fontSize: 10),
              ),
          ],
        ),
        if (review.comment != null && review.comment!.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            review.comment!,
            style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logo != null && logo.isNotEmpty)
            SizedBox(
              width: 18,
              height: 18,
              child: Image.network(
                logo,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _fallbackIcon(c),
              ),
            )
          else
            _fallbackIcon(c),
          const SizedBox(width: 6),
          Text(
            method.name,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon(AppColor c) => Icon(
    Icons.account_balance_wallet_outlined,
    size: 14,
    color: c.primary,
  );
}

// ─── Skeleton helpers ─────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.c, required this.height, this.width});
  final AppColor c;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = isLight ? const Color(0xFFE5E7EB) : const Color(0xFF2A2A2A);
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip({this.width = 90});
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return _Skeleton(c: c, height: 30, width: width);
  }
}

class _LoadingDetailMethodsRow extends StatelessWidget {
  const _LoadingDetailMethodsRow({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Payment methods',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _SkeletonChip(width: 96),
                _SkeletonChip(width: 104),
                _SkeletonChip(width: 86),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantCardSkeleton extends StatelessWidget {
  const _MerchantCardSkeleton({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Skeleton(c: c, height: 44, width: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Skeleton(c: c, height: 10, width: 70),
                    const SizedBox(height: 6),
                    _Skeleton(c: c, height: 14, width: 160),
                  ],
                ),
              ),
              _Skeleton(c: c, height: 24, width: 72),
            ],
          ),
          const SizedBox(height: 14),
          _SectionDivider(c: c),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SkeletonChip(width: 90),
              _SkeletonChip(width: 84),
              _SkeletonChip(width: 94),
            ],
          ),
          const SizedBox(height: 12),
          _Skeleton(c: c, height: 11),
          const SizedBox(height: 8),
          _Skeleton(c: c, height: 11, width: 230),
          const SizedBox(height: 12),
          _SectionDivider(c: c),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SkeletonChip(width: 88),
              _SkeletonChip(width: 110),
              _SkeletonChip(width: 96),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewsLoadingCard extends StatelessWidget {
  const _ReviewsLoadingCard({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Skeleton(c: c, height: 16, width: 16),
              const SizedBox(width: 8),
              _Skeleton(c: c, height: 14, width: 64),
              const Spacer(),
              _Skeleton(c: c, height: 24, width: 46),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(2, (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 1 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Skeleton(c: c, height: 12, width: 76),
                      const Spacer(),
                      _Skeleton(c: c, height: 10, width: 46),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Skeleton(c: c, height: 10),
                  const SizedBox(height: 6),
                  _Skeleton(c: c, height: 10, width: 210),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}