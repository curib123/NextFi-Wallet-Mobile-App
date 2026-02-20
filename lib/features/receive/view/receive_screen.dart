// lib/features/receive/view/receive_screen.dart
import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/modal/edit_federation_modal.dart';
import 'package:next_fi/common/components/modal/receive_qr_modal.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/features/price_chart/view/price_chart_card.dart';
import 'package:next_fi/features/receive/view_model/receive_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'widgets/token_switch.dart';
import 'widgets/qr_preview_card.dart';
import 'widgets/address_row.dart';
import 'widgets/safety_note.dart';

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
          title: Text(
            'Receive',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800),
          ),
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
                PriceChartCard(
                  title: token.toUpperCase(),
                  token: token.toUpperCase(),
                ),
                const SizedBox(height: 12),
                QrPreviewCard(
                  address: s.address,
                  token: token,
                  onTap: () => showReceiveQrModal(context, s),
                ),
                const SizedBox(height: 16),

                AddressRow(address: s.address),
                const SizedBox(height: 16),
                _buildFederationSection(context, receiveVM),
                const SizedBox(height: 16),

                SafetyNote(text: receiveVM.safetyNote),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFederationSection(BuildContext context, ReceiveVM vm) {
    final c = AppColor.of(context);

    if (vm.federationLoading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Loading federation address...',
                style: TextStyle(color: c.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (vm.federationAddresses.isEmpty) {
      final domain = vm.federationDomain;
      final hasDomain = domain != null && domain.trim().isNotEmpty;
      final hasTypedAlias = vm.federationAliasDraft.trim().isNotEmpty;
      final canGenerate =
          !vm.generatingFederation &&
          (!hasTypedAlias || vm.isAliasAvailable == true);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No federation address yet',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Generate one linked to this public address.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: vm.setFederationAliasDraft,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
              ],
              decoration: InputDecoration(
                hintText: 'Type alias (e.g. johnpaulcurib)',
                suffixText: hasDomain ? '*$domain' : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (vm.federationAddressPreview.isNotEmpty)
              Text(
                vm.federationAddressPreview,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppOutlinedButton.icon(
                onPressed: vm.checkingAliasAvailability
                    ? null
                    : () => vm.checkAliasAvailability(),
                icon: vm.checkingAliasAvailability
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primary,
                        ),
                      )
                    : Icon(LucideIcons.search, size: 16, color: c.primary),
                label: Text(
                  vm.checkingAliasAvailability
                      ? 'Checking...'
                      : 'Check availability',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if (vm.aliasAvailabilityMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                vm.aliasAvailabilityMessage!,
                style: TextStyle(
                  color: vm.isAliasAvailable == true
                      ? c.success
                      : (vm.isAliasAvailable == false
                            ? c.error
                            : c.textSecondary),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (vm.generateFederationError != null) ...[
              const SizedBox(height: 8),
              Text(
                vm.generateFederationError!,
                style: TextStyle(
                  color: c.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppElevatedButton.icon(
                onPressed: canGenerate
                    ? () async {
                        final ok = await vm.generateFederationAddress();
                        if (!context.mounted) return;
                        if (ok) {
                          showFloatingSnackBar(
                            context,
                            message: 'Federation address generated',
                            type: SnackBarType.success,
                          );
                        }
                      }
                    : null,
                icon: vm.generatingFederation
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.sparkles, size: 16),
                label: Text(
                  vm.generatingFederation
                      ? 'Generating...'
                      : 'Generate Federation',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'Federation Address',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final item in vm.federationAddresses)
            ListTile(
              dense: true,
              title: Text(
                '${item.alias}*${vm.federationDomain ?? item.domain}',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                item.accountId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.edit2, size: 18, color: c.primary),
                    onPressed: () =>
                        showEditFederationModal(context, vm: vm, item: item),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.copy, size: 18, color: c.primary),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: item.federationAddress),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
