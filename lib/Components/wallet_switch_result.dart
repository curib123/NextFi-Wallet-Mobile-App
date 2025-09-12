import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Services/seed_storage.dart';

/// Result returned by the switch-wallet sheet.
class WalletSwitchResult {
  final String? chosenWalletId;
  final bool createNew;

  const WalletSwitchResult({this.chosenWalletId, this.createNew = false});
}

/// Open a modern bottom sheet to switch the active wallet.
///
/// Returns [WalletSwitchResult] with either `chosenWalletId` or `createNew=true`.
Future<WalletSwitchResult?> showWalletSwitchSheet(
    BuildContext context, {
      String? currentActiveId,
      bool allowGenerate = true,
      String generateLabel = 'Generate New Wallet',
    }) async {
  final colors = AppColor.of(context);
  final wallets = await SeedStorage.listWallets();

  return showModalBottomSheet<WalletSwitchResult>(
    context: context,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: _WalletSwitchBody(
          colors: colors,
          wallets: wallets,
          activeId: currentActiveId,
          allowGenerate: allowGenerate,
          generateLabel: generateLabel,
        ),
      );
    },
  );
}

class _WalletSwitchBody extends StatelessWidget {
  const _WalletSwitchBody({
    required this.colors,
    required this.wallets,
    required this.activeId,
    required this.allowGenerate,
    required this.generateLabel,
  });

  final AppColor colors;
  final List<dynamic> wallets; // List<WalletMetaModel>
  final String? activeId;
  final bool allowGenerate;
  final String generateLabel;

  static const double _pad = 16;
  static const double _radius = 14;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _SheetHandle(colors: colors),
          ListTile(
            title: Text(
              "Switch Wallet",
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Pick an existing wallet or create a new one',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            ),
          ),
          const Divider(height: 1),

          // Wallet list (or empty state)
          Flexible(
            child: wallets.isEmpty
                ? _emptyState(context)
                : ListView.separated(
              shrinkWrap: true,
              itemCount: wallets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = wallets[i];
                final bool isActive = m.id == activeId;
                return ListTile(
                  leading: Icon(
                    isActive ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    color: isActive ? colors.success : colors.textSecondary,
                  ),
                  title: Text(
                    m.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: (m.publicAddress?.isNotEmpty ?? false)
                      ? Text(
                    m.publicAddress!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  )
                      : null,
                  trailing: isActive
                      ? Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.success.withOpacity(.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.success.withOpacity(.35)),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: colors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  )
                      : null,
                  onTap: () {
                    Navigator.pop(
                      context,
                      WalletSwitchResult(chosenWalletId: m.id),
                    );
                  },
                );
              },
            ),
          ),

          // Footer actions
          Padding(
            padding: const EdgeInsets.fromLTRB(_pad, 12, _pad, 16),
            child: Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Close',
                    icon: LucideIcons.x,
                    type: ButtonType.outlined,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (allowGenerate) const SizedBox(width: 10),
                if (allowGenerate)
                  Expanded(
                    child: CustomButton(
                      text: generateLabel,
                      icon: LucideIcons.sparkles,
                      onPressed: () {
                        Navigator.pop(context, const WalletSwitchResult(createNew: true));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: colors.border.withOpacity(.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wallet, size: 40, color: colors.textSecondary),
            const SizedBox(height: 10),
            Text(
              'No wallets yet',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first wallet to get started.',
              style: TextStyle(color: colors.textSecondary, height: 1.45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.colors});
  final AppColor colors;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
