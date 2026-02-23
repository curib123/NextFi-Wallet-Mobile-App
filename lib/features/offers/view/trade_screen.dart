import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';

class TradeScreen extends StatelessWidget {
  const TradeScreen({super.key, required this.offer});

  final OfferModel offer;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final pair = '${offer.asset}/${offer.fiatCurrency}';
    final typeLabel = offer.type == null
        ? 'Trade'
        : offer.type!.name.toUpperCase();
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'Start Trade',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: c.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$typeLabel $pair',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Offer ID: ${offer.id}',
                        style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.construction_rounded,
                  color: c.textSecondary.withOpacity(0.8),
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  'Trade flow is coming next',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This screen will include amount input, payment method, and confirmation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
