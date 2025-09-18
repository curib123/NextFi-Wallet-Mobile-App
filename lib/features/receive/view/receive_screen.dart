// lib/features/receive/view/receive_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/features/price_chart/view/price_chart_card.dart';
import 'package:next_fi/features/receive/model/receive_state.dart';
import 'package:next_fi/features/receive/view_model/receive_vm.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'widgets/token_switch.dart';
import 'widgets/qr_preview_card.dart';
import 'widgets/address_row.dart';
import 'widgets/safety_note.dart';
import 'widgets/token_pill.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({
    super.key,
    required this.address,
    required this.xlmBalance,
    required this.usdcBalance,
    this.initialToken = 'XLM',
  });

  final String address;
  final double xlmBalance;
  final double usdcBalance;
  final String initialToken;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return ChangeNotifierProvider(
      create: (_) => ReceiveVM(
        address: address,
        xlmBalance: xlmBalance,
        usdcBalance: usdcBalance,
        initialToken: initialToken,
      ),
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: c.surface,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text('Receive', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        ),
        body: Consumer2<ReceiveVM, CurrencyVM>(
          builder: (context, receiveVM, currencyVM, _) {
            final s = receiveVM.state; // ReceiveState
            final token = s.token; // 'XLM' or 'USDC'
            // fiat (currency.fiat) is available here if you want to show it alongside chart/balances

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TokenSwitch(
                  xlmSelected: s.xlmSelected,
                  onSelectXLM: receiveVM.selectXLM,
                  onSelectUSDC: receiveVM.selectUSDC,
                ),
                const SizedBox(height: 12),
                PriceChartCard(title: token.toUpperCase(), token: token.toUpperCase()),
                const SizedBox(height: 12),
                QrPreviewCard(
                  address: s.address,
                  token: token,
                  onTap: () => _showQrDialog(context, s),
                ),
                const SizedBox(height: 16),

                AddressRow(address: s.address),
                const SizedBox(height: 16),

                SafetyNote(text: receiveVM.safetyNote),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context, ReceiveState s) {
    final c = AppColor.of(context);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: c.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TokenPill(token: s.token),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.white,
                  child: QrImageView(data: s.address, version: QrVersions.auto, size: 260),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                s.address,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontFamily: 'monospace', fontSize: 12.5, height: 1.2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: s.address));
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        // snackbar handled by AddressRow normally; here keep it quiet
                      },
                      icon: Icon(LucideIcons.copy, size: 18, color: c.primary),
                      label: Text('Copy', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.primary.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, size: 18, color: Colors.white),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
