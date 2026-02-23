import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';

class OfferDetailsModal extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isBuy = offer.type == OfferType.buy;
    final typeColor = isBuy ? const Color(0xFF0EA968) : c.primary;
    final typeText = isBuy ? 'BUY' : 'SELL';
    final statusText = offer.status?.name.toUpperCase() ?? 'UNKNOWN';

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: c.border.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Pill(
                      label: typeText,
                      fg: typeColor,
                      bg: typeColor.withOpacity(0.12),
                      border: typeColor.withOpacity(0.28),
                    ),
                    _Pill(
                      label: statusText,
                      fg: c.textPrimary,
                      bg: c.background.withOpacity(0.42),
                      border: c.border.withOpacity(0.24),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${offer.asset}/${offer.fiatCurrency}',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.primary.withOpacity(0.22)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: c.primary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Live price ${marketPrice ?? '-'}',
                          style: TextStyle(
                            color: c.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  c: c,
                  title: 'Trade limits',
                  children: [
                    _kv(c, 'Min amount', '${offer.minAmount ?? '-'}'),
                    _kv(c, 'Max amount', '${offer.maxAmount ?? '-'}'),
                    _kv(c, 'Total qty', '${offer.totalQty ?? '-'}'),
                    _kv(c, 'Available qty', '${offer.availableQty ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 10),
                _Section(
                  c: c,
                  title: 'Details',
                  children: [
                    _kv(c, 'Payment window', '${offer.paymentWindowMinutes ?? '-'} minutes'),
                    _kv(c, 'Visible', offer.isVisible ? 'Yes' : 'No'),
                    _kv(c, 'Seller ID', offer.sellerId ?? '-'),
                    _kv(
                      c,
                      'Payment methods',
                      offer.paymentMethodIds.join(', ').isEmpty
                          ? '-'
                          : offer.paymentMethodIds.join(', '),
                    ),
                    if ((offer.autoReply ?? '').trim().isNotEmpty)
                      _kv(c, 'Auto reply', offer.autoReply!.trim()),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: AppElevatedButton(
                    onPressed: onTradeNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Trade Now',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(AppColor c, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          children: [
            TextSpan(
              text: '$k: ',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.c,
    required this.title,
    required this.children,
  });

  final AppColor c;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: c.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11.2,
          height: 1,
        ),
      ),
    );
  }
}
