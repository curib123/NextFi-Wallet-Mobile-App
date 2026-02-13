import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/modal/ramp_provider.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:provider/provider.dart';


/// Handles ramp operations (buy/sell) for the wallet
/// Integrates with HeaderSection Buy/Sell actions
class RampHandler {
  /// Open Buy modal with token and currency selection
  static Future<void> handleDeposit({
    required BuildContext context,
    required String stellarAddress,
    FiatCurrency? initialCurrency,
    String? initialToken,
    String? region,
  }) async {
    final walletService = context.read<StellarWalletServices>();

    // Show provider selection modal with currency and token selection
    final provider = await showRampProviderModal(
      context: context,
      type: RampTransactionType.buy,
      initialCurrency: initialCurrency,
      initialToken: initialToken,
      region: region,
    );

    if (provider == null || !context.mounted) return;

    // Open provider (currency is handled by the modal selection)
    final result = await walletService.buyXlmWithProvider(
      stellarAddress: stellarAddress,
      provider: provider,
      amount: null,
      currency: initialCurrency,
    );

    if (!context.mounted) return;

    // Show error if failed (success is handled by activity logging)
    if (!result.success) {
      showFloatingSnackBar(
        context,
        message: result.errorMessage ?? 'Failed to open provider',
        type: SnackBarType.error,
      );
    }
  }

  /// Open Sell modal with token and currency selection
  static Future<void> handleWithdraw({
    required BuildContext context,
    required String stellarAddress,
    FiatCurrency? initialCurrency,
    String? initialToken,
    String? region,
  }) async {
    final walletService = context.read<StellarWalletServices>();

    // Show provider selection modal with currency and token selection
    final provider = await showRampProviderModal(
      context: context,
      type: RampTransactionType.sell,
      initialCurrency: initialCurrency,
      initialToken: initialToken,
      region: region,
    );

    if (provider == null || !context.mounted) return;

    // Open provider (currency is handled by the modal selection)
    final result = await walletService.sellXlmWithProvider(
      stellarAddress: stellarAddress,
      provider: provider,
      amount: null,
      currency: initialCurrency,
    );

    if (!context.mounted) return;

    // Show error if failed
    if (!result.success) {
      showFloatingSnackBar(
        context,
        message: result.errorMessage ?? 'Failed to open provider',
        type: SnackBarType.error,
      );
    }
  }

  /// Open Swap modal (use for external DEX swap)
  static Future<void> handleDexSwap({
    required BuildContext context,
    required String stellarAddress,
  }) async {
    final walletService = context.read<StellarWalletServices>();

    // Show provider selection modal
    final provider = await showRampProviderModal(
      context: context,
      type: RampTransactionType.swap,
    );

    if (provider == null || !context.mounted) return;

    // Open provider
    final result = await walletService.swapOnDex(
      stellarAddress: stellarAddress,
      provider: provider,
    );

    if (!context.mounted) return;

    // Show error if failed
    if (!result.success) {
      showFloatingSnackBar(
        context,
        message: result.errorMessage ?? 'Failed to open provider',
        type: SnackBarType.error,
      );
    }
  }
}

/// Example: Updated HeaderSection action tiles with ramp integration
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppColor colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = colors.primary.withOpacity(0.05);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Icon(icon, color: colors.primary, size: 25),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.15,
          ),
        ),
      ],
    );
  }
}


/// Alternative: Standalone ramp action buttons widget
class RampQuickActions extends StatelessWidget {
  final AppColor colors;
  final String stellarAddress;
  final FiatCurrency? defaultCurrency;
  final String? defaultToken;
  final String? region;

  const RampQuickActions({
    super.key,
    required this.colors,
    required this.stellarAddress,
    this.defaultCurrency,
    this.defaultToken,
    this.region,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionTile(
            colors: colors,
            icon: LucideIcons.dollarSign,
            label: 'Buy',
            onTap: () => RampHandler.handleDeposit(
              context: context,
              stellarAddress: stellarAddress,
              initialCurrency: defaultCurrency,
              initialToken: defaultToken,
              region: region,
            ),
          ),
          _ActionTile(
            colors: colors,
            icon: LucideIcons.banknote,
            label: 'Sell',
            onTap: () => RampHandler.handleWithdraw(
              context: context,
              stellarAddress: stellarAddress,
              initialCurrency: defaultCurrency,
              initialToken: defaultToken,
              region: region,
            ),
          ),
          _ActionTile(
            colors: colors,
            icon: LucideIcons.arrowLeftRight,
            label: 'DEX Swap',
            onTap: () => RampHandler.handleDexSwap(
              context: context,
              stellarAddress: stellarAddress,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full Buy/Sell button row (alternative design)
class RampActionButtons extends StatelessWidget {
  final String stellarAddress;
  final FiatCurrency? defaultCurrency;
  final String? defaultToken;
  final String? region;

  const RampActionButtons({
    super.key,
    required this.stellarAddress,
    this.defaultCurrency,
    this.defaultToken,
    this.region,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Buy button
          Expanded(
            child: _RampButton(
              label: 'Buy Crypto',
              icon: LucideIcons.dollarSign,
              colors: colors,
              gradient: LinearGradient(
                colors: [
                  Colors.green,
                  Colors.green.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onPressed: () => RampHandler.handleDeposit(
                context: context,
                stellarAddress: stellarAddress,
                initialCurrency: defaultCurrency,
                initialToken: defaultToken,
                region: region,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Sell button
          Expanded(
            child: _RampButton(
              label: 'Sell Crypto',
              icon: LucideIcons.banknote,
              colors: colors,
              gradient: LinearGradient(
                colors: [
                  Colors.orange,
                  Colors.orange.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onPressed: () => RampHandler.handleWithdraw(
                context: context,
                stellarAddress: stellarAddress,
                initialCurrency: defaultCurrency,
                initialToken: defaultToken,
                region: region,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient button for ramp actions
class _RampButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final AppColor colors;
  final Gradient gradient;
  final VoidCallback onPressed;

  const _RampButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.gradient,
    required this.onPressed,
  });

  @override
  State<_RampButton> createState() => _RampButtonState();
}

class _RampButtonState extends State<_RampButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _isPressed ? 0.95 : 1.0,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}