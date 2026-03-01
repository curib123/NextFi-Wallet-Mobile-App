import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/reusable_model/asset_model.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:intl/intl.dart';

Future<void> showTokenSelector(
    BuildContext context,
    String address,
    double xlmBalance,
    double usdcBalance, {
      required Widget Function(String address, String token, double balance)
      screenBuilder,
      String title = 'Select Asset',
    }) async {
  final colors = AppColor.of(context);
  final assetVM = context.read<AssetVM>();
  final assets = assetVM.assets;

  double balanceFor(AssetModel a) {
    switch (a.symbol.toUpperCase()) {
      case 'XLM':
        return xlmBalance;
      case 'USDC':
        return usdcBalance;
      default:
        return 0.0;
    }
  }

  String subtitleFor(AssetModel a) {
    if (a.isNative) return '${a.name} • ${a.chain}';
    final chainNet = '${a.chain}/${a.network}';
    if ((a.assetCode ?? '').isNotEmpty && (a.issuer ?? '').isNotEmpty) {
      return '${a.assetCode} • $chainNet';
    }
    if ((a.contract ?? '').isNotEmpty) {
      return '${a.symbol} (contract) • $chainNet';
    }
    return '${a.name} • $chainNet';
  }

  String? logoFor(AssetModel a) {
    if (a.primaryLogo.isNotEmpty) return a.primaryLogo;
    return assetVM.logoFor(a.symbol);
  }

  void open(AssetModel a) {
    final bal = balanceFor(a);
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screenBuilder(address, a.symbol, bal)),
    );
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColor.of(context).surface,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _TokenSelectorSheet(
      colors: colors,
      title: title,
      assets: assets,
      balanceFor: balanceFor,
      subtitleFor: subtitleFor,
      logoFor: logoFor,
      onSelect: open,
    ),
  );
}

class _TokenSelectorSheet extends StatefulWidget {
  const _TokenSelectorSheet({
    required this.colors,
    required this.title,
    required this.assets,
    required this.balanceFor,
    required this.subtitleFor,
    required this.logoFor,
    required this.onSelect,
  });

  final AppColor colors;
  final String title;
  final List<AssetModel> assets;
  final double Function(AssetModel) balanceFor;
  final String Function(AssetModel) subtitleFor;
  final String? Function(AssetModel) logoFor;
  final void Function(AssetModel) onSelect;

  @override
  State<_TokenSelectorSheet> createState() => _TokenSelectorSheetState();
}

class _TokenSelectorSheetState extends State<_TokenSelectorSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        color: widget.colors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: widget.colors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              LucideIcons.coins,
              color: AppColor.of(context).onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: widget.colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.assets.length} assets available',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colors.textSecondary,
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: widget.colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColor.of(context).textPrimary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildHeader(),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  shrinkWrap: true,
                  itemCount: widget.assets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final asset = widget.assets[i];
                    final balance = widget.balanceFor(asset);
                    return _TokenTile(
                      colors: widget.colors,
                      asset: asset,
                      balance: balance,
                      subtitle: widget.subtitleFor(asset),
                      logoUrl: widget.logoFor(asset),
                      onTap: () => widget.onSelect(asset),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenTile extends StatefulWidget {
  const _TokenTile({
    required this.colors,
    required this.asset,
    required this.balance,
    required this.subtitle,
    required this.logoUrl,
    required this.onTap,
  });

  final AppColor colors;
  final AssetModel asset;
  final double balance;
  final String subtitle;
  final String? logoUrl;
  final VoidCallback onTap;

  @override
  State<_TokenTile> createState() => _TokenTileState();
}

class _TokenTileState extends State<_TokenTile> {
  bool _isPressed = false;

  String _formatBalance(double v) {
    final formatter = NumberFormat.compact();
    if (v >= 1000000) return formatter.format(v);
    if (v >= 100) return v.toStringAsFixed(2);
    if (v >= 1) return v.toStringAsFixed(4);
    if (v > 0) return v.toStringAsFixed(6);
    return '0.00';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPressed
                ? widget.colors.primary.withValues(alpha: 0.3)
                : widget.colors.border.withValues(alpha: 0.2),
            width: _isPressed ? 2 : 1,
          ),
          boxShadow: _isPressed
              ? [
            BoxShadow(
              color: widget.colors.primary.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            // Logo
            _TokenLogo(
              colors: widget.colors,
              logoUrl: widget.logoUrl,
              isNative: widget.asset.isNative,
              symbol: widget.asset.symbol,
            ),
            const SizedBox(width: 14),

            // Token info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.asset.symbol.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (widget.asset.isNative) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: widget.colors.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Native',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColor.of(context).onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.colors.textSecondary.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Balance & arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatBalance(widget.balance),
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
                    color: widget.colors.primary.withValues(alpha: 0.1),
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

class _TokenLogo extends StatelessWidget {
  const _TokenLogo({
    required this.colors,
    required this.logoUrl,
    required this.isNative,
    required this.symbol,
  });

  final AppColor colors;
  final String? logoUrl;
  final bool isNative;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;

    Widget fallback() {
      final gradientColors = isNative
          ? [colors.primary, colors.accent]
          : [colors.textSecondary.withValues(alpha: 0.2), colors.border];

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: isNative
              ? [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Center(
          child: Text(
            symbol.isNotEmpty ? symbol[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isNative ? AppColor.of(context).onPrimary : colors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (logoUrl == null || logoUrl!.isEmpty) {
      return fallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
