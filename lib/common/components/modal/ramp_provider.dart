import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/helper/link_opener/link_opener.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:provider/provider.dart';

/// Show ramp provider selection modal with currency and token selection
/// Returns selected provider or null if cancelled
Future<RampProvider?> showRampProviderModal({
  required BuildContext context,
  required RampTransactionType type,
  FiatCurrency? initialCurrency,
  String? initialToken, // 'XLM' or 'USDC'
  String? region,
}) {
  return showModalBottomSheet<RampProvider>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => RampProviderModal(
      type: type,
      initialCurrency: initialCurrency,
      initialToken: initialToken,
      region: region,
    ),
  );
}

/// Ramp provider selection modal with currency and token selection
class RampProviderModal extends StatefulWidget {
  final RampTransactionType type;
  final FiatCurrency? initialCurrency;
  final String? initialToken;
  final String? region;

  const RampProviderModal({
    super.key,
    required this.type,
    this.initialCurrency,
    this.initialToken,
    this.region,
  });

  @override
  State<RampProviderModal> createState() => _RampProviderModalState();
}

class _RampProviderModalState extends State<RampProviderModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  late FiatCurrency _selectedCurrency;
  late String _selectedToken;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency ?? FiatCurrency.usd;
    _selectedToken = widget.initialToken ?? 'XLM';

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildHandle(AppColor colors) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        color: colors.border.withOpacity(0.5),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  Widget _buildSelectors(AppColor colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Token selector (XLM/USDC)
          Expanded(
            child: _SelectorChip(
              colors: colors,
              label: 'Token',
              value: _selectedToken,
              icon: LucideIcons.coins,
              onTap: () => _showTokenSelector(colors),
            ),
          ),
          const SizedBox(width: 12),
          // Currency selector
          Expanded(
            child: _SelectorChip(
              colors: colors,
              label: 'Currency',
              value: _selectedCurrency.code,
              icon: LucideIcons.banknote,
              onTap: () => _showCurrencySelector(colors),
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenSelector(AppColor colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Select Token',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              _buildTokenOption(ctx, 'XLM', 'Stellar Lumens', colors),
              _buildTokenOption(ctx, 'USDC', 'USD Coin', colors),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencySelector(AppColor colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Select Currency',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                ...FiatCurrency.values.map((currency) =>
                    _buildCurrencyOption(ctx, currency, colors)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenOption(BuildContext ctx, String token, String name, AppColor colors) {
    final isSelected = _selectedToken == token;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedToken = token);
          Navigator.pop(ctx);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    token[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  LucideIcons.check,
                  color: colors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(BuildContext ctx, FiatCurrency currency, AppColor colors) {
    final isSelected = _selectedCurrency == currency;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedCurrency = currency);
          Navigator.pop(ctx);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    currency.symbol,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.code,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      currency.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  LucideIcons.check,
                  color: colors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColor colors, String title, int providerCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: colors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _getIconForType(widget.type),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$providerCount ${providerCount == 1 ? 'provider' : 'providers'} available',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    // Safety check for wallet service
    StellarWalletServices? walletService;
    try {
      walletService = context.read<StellarWalletServices>();
    } catch (e) {
      // If provider not available, show error
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Center(
            child: Text(
              'Wallet service not available',
              style: TextStyle(color: colors.textPrimary),
            ),
          ),
        ),
      );
    }

    final providers = walletService.getAvailableRampProviders(
      type: widget.type,
      currency: _selectedCurrency,
      region: widget.region,
    );

    final title = switch (widget.type) {
      RampTransactionType.buy => 'Buy $_selectedToken',
      RampTransactionType.sell => 'Sell $_selectedToken',
      RampTransactionType.swap => 'Swap Assets',
    };

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(colors),
                _buildSelectors(colors),
                const SizedBox(height: 8),
                _buildHeader(colors, title, providers.length),
                const SizedBox(height: 16),
                Flexible(
                  child: providers.isEmpty
                      ? _EmptyProviders(colors: colors, type: widget.type)
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    shrinkWrap: true,
                    itemCount: providers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _ProviderTile(
                        info: providers[index],
                        colors: colors,
                        selectedToken: _selectedToken,
                        selectedCurrency: _selectedCurrency,
                        onTap: () => Navigator.pop(context, providers[index].provider),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(RampTransactionType type) {
    return switch (type) {
      RampTransactionType.buy => LucideIcons.dollarSign,
      RampTransactionType.sell => LucideIcons.banknote,
      RampTransactionType.swap => LucideIcons.arrowLeftRight,
    };
  }
}

/// Individual provider tile
class _ProviderTile extends StatefulWidget {
  final ProviderInfo info;
  final AppColor colors;
  final String selectedToken;
  final FiatCurrency selectedCurrency;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.info,
    required this.colors,
    required this.selectedToken,
    required this.selectedCurrency,
    required this.onTap,
  });

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
  bool _isPressed = false;

  void _handleTap() {
    // If provider has a URL, open it with LinkOpener
    if (widget.info.provider.webUrl != null && widget.info.provider.webUrl!.isNotEmpty) {
      LinkOpener.open(
        context,
        widget.info.provider.webUrl!,
        fallbackLabel: '${widget.info.provider.name} link',
      );
    }
    // Still call the original onTap to close the modal
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPressed
                ? widget.colors.primary.withOpacity(0.3)
                : widget.colors.border.withOpacity(0.2),
            width: _isPressed ? 2 : 1,
          ),
          boxShadow: _isPressed
              ? [
            BoxShadow(
              color: widget.colors.primary.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Provider icon
            _ProviderLogo(
              colors: widget.colors,
              provider: widget.info.provider,
            ),

            const SizedBox(width: 14),

            // Provider details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.info.provider.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: widget.colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.info.kycRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'KYC',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: widget.colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.info.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.colors.textSecondary.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Fee & action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.info.estimatedFees != null)
                  Text(
                    widget.info.estimatedFees!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.colors.textPrimary,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.colors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.arrowRight,
                        size: 12,
                        color: widget.colors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Provider logo matching token logo style
class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({
    required this.colors,
    required this.provider,
  });

  final AppColor colors;
  final RampProvider provider;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          provider.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Selector chip for currency and token selection
class _SelectorChip extends StatelessWidget {
  final AppColor colors;
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectorChip({
    required this.colors,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.border.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no providers available
class _EmptyProviders extends StatelessWidget {
  final AppColor colors;
  final RampTransactionType type;

  const _EmptyProviders({
    required this.colors,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.textSecondary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.searchX,
              size: 48,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No providers available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No providers support this transaction type in your region.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}