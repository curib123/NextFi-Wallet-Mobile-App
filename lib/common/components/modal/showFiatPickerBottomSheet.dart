// lib/common/components/fiat_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

/// Call this to open the modal. Returns the selected fiat code (e.g., "php") or null if cancelled.
Future<String?> showFiatPickerBottomSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColor.of(context).surface,
    builder: (_) => const _FiatPickerSheet(),
  );
}

class _FiatPickerSheet extends StatefulWidget {
  const _FiatPickerSheet();

  @override
  State<_FiatPickerSheet> createState() => _FiatPickerSheetState();
}

class _FiatPickerSheetState extends State<_FiatPickerSheet>
    with SingleTickerProviderStateMixin {
  late String _selected;
  String _searchQuery = '';
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final current = context.read<CurrencyVM>().fiat.toLowerCase();
    _selected = _kFiats.any((f) => f.code == current) ? current : 'usd';

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

  List<_Fiat> get _filteredFiats {
    if (_searchQuery.isEmpty) return _kFiats;
    final query = _searchQuery.toLowerCase();
    return _kFiats.where((f) {
      return f.code.toLowerCase().contains(query) ||
          f.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _close([String? result]) async {
    await _animController.reverse();
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  void _selectCurrency(String code) {
    context.read<CurrencyVM>().setFiat(code);
    _close(code);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final filteredFiats = _filteredFiats;

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
                color: AppColor.of(context).textPrimary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),

              // Header
              Padding(
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
                            color: colors.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        LucideIcons.badgeDollarSign,
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
                            'Select Currency',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_kFiats.length} currencies available',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: AppColor.of(context).surface,
                      child: InkWell(
                        onTap: () => _close(null),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.x,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search currencies...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _searchQuery = ''),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Currently selected indicator
              if (_searchQuery.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.checkCircle2,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Current: ${_kFiats.firstWhere((f) => f.code == _selected).name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Currency list
              if (filteredFiats.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.searchX,
                        size: 48,
                        color: colors.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No currencies found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try a different search term',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    shrinkWrap: true,
                    itemCount: filteredFiats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final fiat = filteredFiats[i];
                      final isSelected = fiat.code == _selected;
                      return _CurrencyTile(
                        colors: colors,
                        fiat: fiat,
                        isSelected: isSelected,
                        onTap: () => _selectCurrency(fiat.code),
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

class _CurrencyTile extends StatefulWidget {
  const _CurrencyTile({
    required this.colors,
    required this.fiat,
    required this.isSelected,
    required this.onTap,
  });

  final AppColor colors;
  final _Fiat fiat;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CurrencyTile> createState() => _CurrencyTileState();
}

class _CurrencyTileState extends State<_CurrencyTile> {
  bool _isPressed = false;

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
          color: widget.isSelected
              ? widget.colors.primary.withValues(alpha: 0.08)
              : widget.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? widget.colors.primary.withValues(alpha: 0.4)
                : _isPressed
                ? widget.colors.primary.withValues(alpha: 0.3)
                : widget.colors.border.withValues(alpha: 0.2),
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
            BoxShadow(
              color: widget.colors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : _isPressed
              ? [
            BoxShadow(
              color: widget.colors.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            // Flag
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.colors.border.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.fiat.flag,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 14),

            // Currency info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.fiat.code.toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: widget.isSelected
                              ? widget.colors.primary
                              : widget.colors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (widget.isSelected) ...[
                        const SizedBox(width: 8),
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
                            'Active',
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
                    widget.fiat.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.colors.primary
                    : widget.colors.border.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: widget.isSelected
                  ? Icon(
                LucideIcons.check,
                size: 16,
                color: AppColor.of(context).onPrimary,
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// ---- Fiat options (common & PH-focused set) ----
/// Add/remove freely; codes should be lowercase to match CurrencyProvider.
class _Fiat {
  final String code; // e.g., "usd"
  final String name; // e.g., "US Dollar"
  final String flag; // emoji flag
  const _Fiat(this.code, this.name, this.flag);
}

const List<_Fiat> _kFiats = [
  _Fiat('php', 'Philippine Peso', '🇵🇭'),
  _Fiat('usd', 'US Dollar', '🇺🇸'),
  _Fiat('eur', 'Euro', '🇪🇺'),
  _Fiat('jpy', 'Japanese Yen', '🇯🇵'),
  _Fiat('cny', 'Chinese Yuan', '🇨🇳'),
  _Fiat('hkd', 'Hong Kong Dollar', '🇭🇰'),
  _Fiat('sgd', 'Singapore Dollar', '🇸🇬'),
  _Fiat('aud', 'Australian Dollar', '🇦🇺'),
  _Fiat('nzd', 'New Zealand Dollar', '🇳🇿'),
  _Fiat('gbp', 'British Pound', '🇬🇧'),
  _Fiat('cad', 'Canadian Dollar', '🇨🇦'),
  _Fiat('inr', 'Indian Rupee', '🇮🇳'),
  _Fiat('thb', 'Thai Baht', '🇹🇭'),
  _Fiat('idr', 'Indonesian Rupiah', '🇮🇩'),
  _Fiat('myr', 'Malaysian Ringgit', '🇲🇾'),
  _Fiat('vnd', 'Vietnamese Dong', '🇻🇳'),
  _Fiat('twd', 'New Taiwan Dollar', '🇹🇼'),
  _Fiat('krw', 'South Korean Won', '🇰🇷'),
  _Fiat('aed', 'UAE Dirham', '🇦🇪'),
  _Fiat('sar', 'Saudi Riyal', '🇸🇦'),
  _Fiat('brl', 'Brazilian Real', '🇧🇷'),
  _Fiat('mxn', 'Mexican Peso', '🇲🇽'),
  _Fiat('chf', 'Swiss Franc', '🇨🇭'),
  _Fiat('sek', 'Swedish Krona', '🇸🇪'),
  _Fiat('nok', 'Norwegian Krone', '🇳🇴'),
  _Fiat('dkk', 'Danish Krone', '🇩🇰'),
  _Fiat('pln', 'Polish Złoty', '🇵🇱'),
  _Fiat('czk', 'Czech Koruna', '🇨🇿'),
  _Fiat('huf', 'Hungarian Forint', '🇭🇺'),
  _Fiat('try', 'Turkish Lira', '🇹🇷'),
  _Fiat('ils', 'Israeli Shekel', '🇮🇱'),
  _Fiat('ngn', 'Nigerian Naira', '🇳🇬'),
  _Fiat('zar', 'South African Rand', '🇿🇦'),
];
