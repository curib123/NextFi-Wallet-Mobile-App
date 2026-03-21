import 'package:flutter/material.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/send/presentation/screens/send_screen.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/core/widgets/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/core/widgets/modal/token_chooser.dart';

abstract class _S {
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  static const double r10 = 10;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
}

class RecipientListWidget extends StatelessWidget {
  final AppColor colors;
  final void Function(RecipientAddressModel)? onSelect;
  final String? fromAddress;
  final double? xlmBalance;
  final double? usdcBalance;
  final VoidCallback? onLoginPressed;
  final bool showAppBar;

  const RecipientListWidget({
    super.key,
    required this.colors,
    this.onSelect,
    this.fromAddress,
    this.xlmBalance,
    this.usdcBalance,
    this.onLoginPressed,
    this.showAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 360;
    final fabBottom = _S.s20 + mq.padding.bottom;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: colors.surface,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'Recipients',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              iconTheme: IconThemeData(color: colors.textPrimary),
            )
          : null,
      body: Consumer(
        builder: (context, ref, _) {
          final prov = ref.watch(contactListProvider);
          if (!prov.isAuthenticated && !prov.loading) {
            return _NotAuthenticatedView(
              colors: colors,
              onLoginPressed: onLoginPressed,
            );
          }

          if (prov.loading) return _LoadingView(colors: colors);

          final fab = _AddButton(
            colors: colors,
            compact: compact,
            onPressed: () async {
              if (!prov.isAuthenticated) {
                showFloatingSnackBar(
                  context,
                  message: 'Please login first',
                  type: SnackBarType.warning,
                );
                return;
              }
              final saved = await showRecipientUpsertSheet(context);
              if (saved == true && context.mounted) {
                await ref.read(contactListProvider.notifier).refresh();
                if (!context.mounted) return;
                showFloatingSnackBar(
                  context,
                  message: 'Recipient saved',
                  type: SnackBarType.info,
                );
              }
            },
          );

          final Widget body = prov.items.isEmpty
              ? _EmptyRecipients(colors: colors)
              : _RecipientList(
                  colors: colors,
                  items: prov.sortedItems,
                  onSelect: onSelect,
                  fromAddress: fromAddress,
                  xlmBalance: xlmBalance,
                  usdcBalance: usdcBalance,
                  compact: compact,
                  bottomInset: fabBottom + (compact ? 72 : 88),
                );

          return Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: body,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: fabBottom,
                child: Center(child: fab),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final AppColor colors;
  const _LoadingView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            width: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: _S.s16),
          Text(
            'Loading recipients...',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotAuthenticatedView extends StatelessWidget {
  final AppColor colors;
  final VoidCallback? onLoginPressed;

  const _NotAuthenticatedView({required this.colors, this.onLoginPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - v)),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_S.s32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(_S.r24),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.lock,
                      size: 34,
                      color: colors.warning,
                    ),
                  ),
                  const SizedBox(height: _S.s24),
                  Text(
                    'Login Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: _S.s10),
                  Text(
                    'Sign in to view and manage your\nsaved recipient addresses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final AppColor colors;
  final VoidCallback onPressed;
  final bool compact;

  const _AddButton({
    required this.colors,
    required this.onPressed,
    required this.compact,
  });

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: widget.compact ? 48 : 54,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? _S.s20 : _S.s28,
          ),
          decoration: BoxDecoration(
            color: widget.colors.primary,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: widget.colors.primary.withValues(alpha: 0.32),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.colors.primary.withValues(alpha: 0.14),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.userPlus,
                color: AppColor.of(context).onPrimary,
                size: 18,
              ),
              if (!widget.compact) ...[
                const SizedBox(width: _S.s10),
                Text(
                  'Add Recipient',
                  style: TextStyle(
                    color: AppColor.of(context).onPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientList extends StatelessWidget {
  final AppColor colors;
  final List<RecipientAddressModel> items;
  final void Function(RecipientAddressModel)? onSelect;
  final String? fromAddress;
  final double? xlmBalance;
  final double? usdcBalance;
  final bool compact;
  final double bottomInset;

  const _RecipientList({
    required this.colors,
    required this.items,
    this.onSelect,
    this.fromAddress,
    this.xlmBalance,
    this.usdcBalance,
    required this.compact,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        compact ? _S.s12 : _S.s16,
        _S.s16,
        compact ? _S.s12 : _S.s16,
        bottomInset,
      ),
      itemCount: items.length,
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: _S.s8),
      itemBuilder: (context, i) {
        final r = items[i];
        return TweenAnimationBuilder<double>(
          key: ValueKey(r.id),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 260 + (i * 45)),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - v)),
              child: child,
            ),
          ),
          child: RecipientTile(
            colors: colors,
            recipient: r,
            compact: compact,
            onTap: () async {
              if (onSelect != null) {
                HapticFeedback.selectionClick();
                onSelect!(r);
                return;
              }
              final addr = r.address.trim();
              if (addr.isEmpty) {
                showFloatingSnackBar(
                  context,
                  message: 'Wallet not ready',
                  type: SnackBarType.warning,
                );
                return;
              }
              final sender = (fromAddress ?? '').trim();
              if (sender.isEmpty) {
                showFloatingSnackBar(
                  context,
                  message: 'Sender wallet not ready',
                  type: SnackBarType.warning,
                );
                return;
              }
              await showTokenSelector(
                context,
                sender,
                balanceResolver: (asset) {
                  final walletState = ProviderScope.containerOf(
                    context,
                    listen: false,
                  ).read(walletHomeVmProvider).state;
                  return walletState.balancesByAssetId[asset.id] ?? 0.0;
                },
                screenBuilder: (address, token, balance) => SendScreen(
                  address: address,
                  assetId: token,
                  balance: balance,
                  prefillAddress: r.address,
                  prefillName: r.name,
                  onTransactionCompleted: () async {
                    await ProviderScope.containerOf(
                      context,
                      listen: false,
                    ).read(walletHomeVmProvider).onSuccessfulSend();
                  },
                ),
                title: 'Select Asset',
              );
            },
            onEdit: () async {
              final saved = await showRecipientUpsertSheet(context, initial: r);
              if (saved == true && context.mounted) {
                await ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(contactListProvider.notifier).refresh();
                if (!context.mounted) return;
                showFloatingSnackBar(
                  context,
                  message: 'Recipient updated',
                  type: SnackBarType.info,
                );
              }
            },
            onDelete: () async {
              final ok = await _confirmDelete(context, r.name, colors);
              if (ok != true) return;
              if (!context.mounted) return;
              try {
                await ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(contactListProvider.notifier).remove(r.id);
                if (context.mounted) {
                  showFloatingSnackBar(
                    context,
                    message: 'Recipient removed',
                    type: SnackBarType.warning,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showFloatingSnackBar(
                    context,
                    message: 'Failed: ${e.toString()}',
                    type: SnackBarType.error,
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}

class RecipientTile extends StatefulWidget {
  final AppColor colors;
  final RecipientAddressModel recipient;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RecipientTile({
    super.key,
    required this.colors,
    required this.recipient,
    required this.compact,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<RecipientTile> createState() => _RecipientTileState();
}

class _RecipientTileState extends State<RecipientTile> {
  bool _pressed = false;

  String _short(String a) {
    final s = a.trim();
    if (s.length <= 18) return s;
    return '${s.substring(0, 8)}...${s.substring(s.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final accent = Color(widget.recipient.color);
    final c = widget.compact;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: _pressed
              ? colors.surface.withValues(alpha: isDark ? 0.9 : 0.6)
              : AppColor.of(context).surface,
          borderRadius: BorderRadius.circular(_S.r16),
          border: Border.all(
            color: _pressed
                ? accent.withValues(alpha: isDark ? 0.3 : 0.22)
                : colors.border.withValues(alpha: isDark ? 0.2 : 0.25),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_S.r16),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: accent),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  c ? 14 : 17,
                  c ? 12 : 14,
                  c ? 12 : 14,
                  c ? 12 : 14,
                ),
                child: Row(
                  children: [
                    _TileAvatar(
                      accent: accent,
                      name: widget.recipient.name,
                      compact: c,
                    ),
                    SizedBox(width: c ? _S.s10 : _S.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.recipient.name.isEmpty
                                ? 'Unnamed'
                                : widget.recipient.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: c ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _short(widget.recipient.address),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: c ? 11 : 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: c ? _S.s8 : _S.s12),
                    _MoreMenuButton(
                      colors: colors,
                      recipient: widget.recipient,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileAvatar extends StatelessWidget {
  final Color accent;
  final String name;
  final bool compact;

  const _TileAvatar({
    required this.accent,
    required this.name,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_S.r12),
        border: Border.all(color: accent.withValues(alpha: 0.22), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: accent,
          fontSize: compact ? 16 : 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _MoreMenuButton extends StatelessWidget {
  final AppColor colors;
  final RecipientAddressModel recipient;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MoreMenuButton({
    required this.colors,
    required this.recipient,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showSheet(context);
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(_S.r10),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Icon(
          LucideIcons.moreVertical,
          color: colors.textSecondary,
          size: 16,
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColor.of(context).surface,
      isScrollControlled: true,
      builder: (ctx) => _ActionSheet(
        colors: colors,
        isDark: isDark,
        recipient: recipient,
        onCopy: () async {
          Navigator.pop(ctx);
          await Clipboard.setData(ClipboardData(text: recipient.address));
          if (context.mounted) {
            showFloatingSnackBar(
              context,
              message: 'Address copied',
              type: SnackBarType.info,
            );
          }
        },
        onEdit: () {
          Navigator.pop(ctx);
          onEdit?.call();
        },
        onDelete: () {
          Navigator.pop(ctx);
          onDelete?.call();
        },
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final AppColor colors;
  final bool isDark;
  final RecipientAddressModel recipient;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionSheet({
    required this.colors,
    required this.isDark,
    required this.recipient,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color(recipient.color);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surface : AppColor.of(context).onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(_S.r24)),
        border: Border(top: BorderSide(color: colors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColor.of(context).textPrimary.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: _S.s20),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _S.s20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(_S.r12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      recipient.name.isNotEmpty
                          ? recipient.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: _S.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipient.name.isEmpty ? 'Unnamed' : recipient.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          recipient.address.length > 16
                              ? '${recipient.address.substring(0, 8)}...${recipient.address.substring(recipient.address.length - 6)}'
                              : recipient.address,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: _S.s16),
            Divider(color: colors.border, height: 1, thickness: 1),
            const SizedBox(height: _S.s8),

            _SheetTile(
              icon: LucideIcons.copy,
              label: 'Copy Address',
              colors: colors,
              onTap: onCopy,
            ),
            _SheetTile(
              icon: LucideIcons.pencil,
              label: 'Edit Recipient',
              colors: colors,
              onTap: onEdit,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _S.s16,
                vertical: _S.s6,
              ),
              child: Divider(color: colors.border, height: 1),
            ),

            _SheetTile(
              icon: LucideIcons.trash2,
              label: 'Remove',
              colors: colors,
              isDestructive: true,
              onTap: onDelete,
            ),

            const SizedBox(height: _S.s8),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final AppColor colors;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_SheetTile> createState() => _SheetTileState();
}

class _SheetTileState extends State<_SheetTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive
        ? widget.colors.error
        : widget.colors.textPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: _S.s12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: _S.s12, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.isDestructive
                    ? widget.colors.error.withValues(alpha: 0.08)
                    : widget.colors.surface)
              : AppColor.of(context).surface,
          borderRadius: BorderRadius.circular(_S.r12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isDestructive
                    ? widget.colors.error.withValues(alpha: 0.1)
                    : widget.colors.surface,
                borderRadius: BorderRadius.circular(_S.r10),
                border: Border.all(color: widget.colors.border, width: 1),
              ),
              child: Icon(widget.icon, color: color, size: 16),
            ),
            const SizedBox(width: _S.s14),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Icon(
              LucideIcons.chevronRight,
              color: widget.colors.textSecondary,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  final AppColor colors;
  const _EmptyRecipients({required this.colors});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 360;

    return SafeArea(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - v)),
              child: child,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? _S.s20 : _S.s32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(_S.r24),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.18),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.users,
                      size: 34,
                      color: colors.primary,
                    ),
                  ),
                  SizedBox(height: compact ? _S.s20 : _S.s24),
                  Text(
                    'No recipients yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: _S.s10),
                  Text(
                    'Save addresses for quick,\nsecure transfers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: compact ? 13 : 14,
                      height: 1.6,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDelete(
  BuildContext context,
  String name,
  AppColor colors,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: isDark ? colors.surface : AppColor.of(context).onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_S.r20),
        side: BorderSide(color: colors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_S.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(_S.r16),
                border: Border.all(
                  color: colors.error.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(LucideIcons.trash2, color: colors.error, size: 24),
            ),
            const SizedBox(height: _S.s16),
            Text(
              'Remove recipient?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: _S.s8),
            Text(
              name.isEmpty
                  ? 'This recipient will be permanently removed.'
                  : '"$name" will be permanently removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                height: 1.55,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: _S.s24),
            Row(
              children: [
                Expanded(
                  child: AppTextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_S.r12),
                        side: BorderSide(color: colors.border, width: 1),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: _S.s12),
                Expanded(
                  child: AppElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: AppColor.of(context).onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_S.r12),
                      ),
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
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
