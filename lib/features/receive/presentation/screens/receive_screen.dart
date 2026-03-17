// lib/features/receive/view/receive_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/widgets/modal/edit_federation_modal.dart';
import 'package:next_fi/core/widgets/modal/receive_qr_modal.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/receive/presentation/viewmodels/receive_state.dart';
import 'package:next_fi/features/receive/presentation/viewmodels/receive_controller.dart';
import 'package:next_fi/features/receive/presentation/viewmodels/receive_view_state.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/receive/presentation/widgets/token_switch.dart';
import 'package:next_fi/features/receive/presentation/widgets/qr_preview_card.dart';
import 'package:next_fi/features/receive/presentation/widgets/address_row.dart';
import 'package:next_fi/features/receive/presentation/widgets/safety_note.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({
    super.key,
    required this.address,
    this.initialToken = 'XLM',
  });

  final String address;
  final String initialToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColor.of(context);
    final assetVm = ref.watch(assetVmProvider);
    final assets = assetVm.assets.where((a) => a.chain == 'stellar').toList();
    final args = ReceiveControllerArgs(
      address: address,
      initialToken: initialToken,
    );
    final controller = ref.read(receiveControllerProvider(args).notifier);
    final s = ref.watch(receiveControllerProvider(args));
    final asset = _resolveSelectedAsset(assetVm, assets, s.selectedAssetKey);
    final token = asset.symbol;
    final switchItems = assets
        .map((a) => TokenSwitchItem(key: a.id, label: a.symbol))
        .toList();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _ReceiveHeroCard(
            token: token,
            items: switchItems,
            selectedKey: asset.id,
            onSelected: controller.selectAsset,
          ),
          const SizedBox(height: 12),
          QrPreviewCard(
            address: s.address,
            token: token,
            onTap: () => showReceiveQrModal(
              context,
              _toReceiveState(s.address, token),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(
            title: '$token Wallet Address',
            subtitle: 'Use this address to receive on Stellar.',
          ),
          const SizedBox(height: 10),
          AddressRow(address: s.address),
          const SizedBox(height: 16),
          _SectionLabel(
            title: 'Federation',
            subtitle: 'Optional human-readable receive aliases.',
          ),
          const SizedBox(height: 10),
          _buildFederationSection(context, ref, args, s),
          const SizedBox(height: 16),
          SafetyNote(text: _safetyNoteFor(asset)),
        ],
      ),
    );
  }

  AssetModel _resolveSelectedAsset(
    AssetVM assetVm,
    List<AssetModel> assets,
    String key,
  ) {
    final resolved = assetVm.findAsset(key);
    if (resolved != null && assets.contains(resolved)) return resolved;
    return assets.isNotEmpty ? assets.first : assetVm.assets.first;
  }

  String _safetyNoteFor(AssetModel asset) {
    if (asset.isNative) {
      return 'Send only ${asset.symbol} on the Stellar network to this address. Sending other assets or from other networks may result in permanent loss.';
    }
    return 'Send only ${asset.symbol} on the Stellar network to this address. A ${asset.symbol} trustline is required to receive funds.';
  }

  ReceiveState _toReceiveState(String address, String token) {
    return ReceiveState(
      address: address,
      token: token,
    );
  }

  Widget _buildFederationSection(
    BuildContext context,
    WidgetRef ref,
    ReceiveControllerArgs args,
    ReceiveViewState vm,
  ) {
    final c = AppColor.of(context);
    final controller = ref.read(receiveControllerProvider(args).notifier);

    if (vm.federationLoading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withValues(alpha: 0.25)),
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
      final hasDomain = domain.trim().isNotEmpty;
      final hasTypedAlias = vm.federationAliasDraft.trim().isNotEmpty;
      final canGenerate =
          !vm.generatingFederation &&
          (!hasTypedAlias || vm.isAliasAvailable == true);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withValues(alpha: 0.25)),
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
              onChanged: controller.setFederationAliasDraft,
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
                    : () => controller.checkAliasAvailability(),
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
                  side: BorderSide(color: c.primary.withValues(alpha: 0.35)),
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
                        final ok = await controller.generateFederationAddress();
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
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onPrimary,
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
                  foregroundColor: c.onPrimary,
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
        border: Border.all(color: c.border.withValues(alpha: 0.25)),
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
                '${item.alias}*${vm.federationDomain.isNotEmpty ? vm.federationDomain : item.domain}',
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
                    onPressed: () => showEditFederationModal(
                      context,
                      args: args,
                      item: item,
                    ),
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

class _ReceiveHeroCard extends StatelessWidget {
  const _ReceiveHeroCard({
    required this.token,
    required this.items,
    required this.selectedKey,
    required this.onSelected,
  });

  final String token;
  final List<TokenSwitchItem> items;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.surface,
            c.surface.withValues(alpha: 0.96),
            c.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.qrCode, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receive $token',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your QR code or wallet address. Network and wallet logic stay unchanged.',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TokenSwitch(
            items: items,
            selectedKey: selectedKey,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3),
        ),
      ],
    );
  }
}

