import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/verification_result_modal.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_dtos.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class PaymentAccountSetupScreen extends StatefulWidget {
  /// [isMerchant] controls copy/flow only; data source is always UserPaymentAccount.
  final bool isMerchant;

  const PaymentAccountSetupScreen({super.key, this.isMerchant = false});

  @override
  State<PaymentAccountSetupScreen> createState() =>
      _PaymentAccountSetupScreenState();
}

class _PaymentAccountSetupScreenState extends State<PaymentAccountSetupScreen>
    with SingleTickerProviderStateMixin {
  final _paymentCore = PaymentMethodAndAccountsCoreService.I;

  final _accountNameCtrl = TextEditingController();
  final _accountNoCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _assetReceiverCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController(); // merchant only

  bool _loading = true;
  bool _saving = false;
  bool _settingActive = false;
  bool _setAsActive = true;

  List<PaymentMethodModel> _methods = const [];
  List<_AccountItem> _accounts = const [];
  PaymentMethodModel? _selectedMethod;
  String? _activeAccountId;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool get _isMerchant => widget.isMerchant;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _accountNameCtrl.dispose();
    _accountNoCtrl.dispose();
    _labelCtrl.dispose();
    _assetReceiverCtrl.dispose();
    _instructionsCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final methods = await _paymentCore.listPaymentMethods(activeOnly: true);
      final raw = await _paymentCore.listMyPaymentAccounts();
      final accounts = raw.map(_AccountItem.fromUser).toList();

      if (!mounted) return;
      setState(() {
        _methods = methods;
        _accounts = accounts;
        _selectedMethod = methods.isNotEmpty ? methods.first : null;
        _activeAccountId = accounts.firstWhereOrNull((a) => a.isActive)?.id;
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Failed to load payment setup: $e');
    }
  }

  Future<void> _createAccount() async {
    final method = _selectedMethod;
    if (method == null) {
      _showSnack('Please select a payment method.');
      return;
    }
    final accountName = _accountNameCtrl.text.trim();
    if (accountName.isEmpty) {
      _showSnack('Account name is required.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      await _paymentCore.createMyPaymentAccount(
        CreateUserPaymentAccountRequest(
          paymentMethodId: method.id,
          accountName: accountName,
          accountNo: _accountNoCtrl.text.trim().isEmpty
              ? null
              : _accountNoCtrl.text.trim(),
          label: _labelCtrl.text.trim().isEmpty
              ? null
              : _labelCtrl.text.trim(),
          assetReceiverAddress: _assetReceiverCtrl.text.trim().isEmpty
              ? null
              : _assetReceiverCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim().isEmpty
              ? null
              : _instructionsCtrl.text.trim(),
          isActive: _setAsActive,
        ),
      );

      _accountNameCtrl.clear();
      _accountNoCtrl.clear();
      _labelCtrl.clear();
      _assetReceiverCtrl.clear();
      _instructionsCtrl.clear();
      if (!mounted) return;
      await _loadAll();
      if (!mounted) return;
      await showVerificationResultModal(
        context,
        title: 'Payment Account Added',
        message: 'Your payment account has been created.',
      );
      if (_isMerchant && mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await showVerificationResultModal(
        context,
        title: 'Create Failed',
        message: e.toString(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setActiveAccount(_AccountItem account) async {
    if (_settingActive || account.isActive) return;
    HapticFeedback.lightImpact();
    setState(() => _settingActive = true);
    try {
      await _paymentCore.updateMyPaymentAccount(
        account.id,
        const UpdateUserPaymentAccountRequest(isActive: true),
      );
      if (!mounted) return;
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to set active: $e');
    } finally {
      if (mounted) setState(() => _settingActive = false);
    }
  }

  Future<void> _editAccount(_AccountItem account) async {
    final accountNameCtrl = TextEditingController(text: account.accountName);
    final accountNoCtrl = TextEditingController(text: account.accountNo ?? '');
    final labelCtrl = TextEditingController(text: account.label ?? '');
    final assetReceiverCtrl = TextEditingController(
      text: account.assetReceiverAddress ?? '',
    );
    final instructionsCtrl = TextEditingController(
      text: account.instructions ?? '',
    );

    bool saving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.of(context).surface,
      builder: (ctx) {
        final c = AppColor.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Payment Account',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FocusField(
                      controller: accountNameCtrl,
                      label: 'Account Name',
                      hint: 'Required',
                      icon: Icons.person_outline_rounded,
                      required: true,
                      action: TextInputAction.next,
                      c: c,
                    ),
                    const SizedBox(height: 10),
                    _FocusField(
                      controller: accountNoCtrl,
                      label: 'Account Number',
                      hint: 'Optional',
                      icon: Icons.tag_rounded,
                      action: TextInputAction.next,
                      c: c,
                    ),
                    const SizedBox(height: 10),
                    _FocusField(
                      controller: labelCtrl,
                      label: 'Label',
                      hint: 'Optional',
                      icon: Icons.label_outline_rounded,
                      action: TextInputAction.next,
                      c: c,
                    ),
                    const SizedBox(height: 10),
                    _FocusField(
                      controller: assetReceiverCtrl,
                      label: 'Asset Receiver Address',
                      hint: 'Optional',
                      icon: Icons.account_balance_wallet_outlined,
                      action: _isMerchant
                          ? TextInputAction.next
                          : TextInputAction.done,
                      c: c,
                    ),
                    if (_isMerchant) ...[
                      const SizedBox(height: 10),
                      _FocusField(
                        controller: instructionsCtrl,
                        label: 'Instructions',
                        hint: 'Optional',
                        icon: Icons.receipt_long_outlined,
                        action: TextInputAction.done,
                        multiline: true,
                        c: c,
                      ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final accountName = accountNameCtrl.text.trim();
                              if (accountName.isEmpty) {
                                _showSnack('Account name is required.');
                                return;
                              }
                              setModal(() => saving = true);
                              try {
                                await _paymentCore.updateMyPaymentAccount(
                                  account.id,
                                  UpdateUserPaymentAccountRequest(
                                    accountName: accountName,
                                    accountNo: accountNoCtrl.text.trim().isEmpty
                                        ? null
                                        : accountNoCtrl.text.trim(),
                                    label: labelCtrl.text.trim().isEmpty
                                        ? null
                                        : labelCtrl.text.trim(),
                                    assetReceiverAddress:
                                        assetReceiverCtrl.text.trim().isEmpty
                                        ? null
                                        : assetReceiverCtrl.text.trim(),
                                    instructions:
                                        instructionsCtrl.text.trim().isEmpty
                                        ? null
                                        : instructionsCtrl.text.trim(),
                                  ),
                                );
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop(true);
                              } catch (e) {
                                if (!ctx.mounted) return;
                                _showSnack('Failed to update account: $e');
                                setModal(() => saving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        saving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    accountNameCtrl.dispose();
    accountNoCtrl.dispose();
    labelCtrl.dispose();
    assetReceiverCtrl.dispose();
    instructionsCtrl.dispose();

    if (saved == true && mounted) {
      await _loadAll();
      if (!mounted) return;
      _showSnack('Payment account updated.');
    }
  }

  Future<void> _deleteAccount(_AccountItem account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = AppColor.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          title: const Text('Delete payment account?'),
          content: Text(
            'This will remove ${account.accountName}.',
            style: TextStyle(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await _paymentCore.deleteMyPaymentAccount(account.id);
      if (!mounted) return;
      await _loadAll();
      if (!mounted) return;
      _showSnack('Payment account deleted.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to delete account: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          _isMerchant ? 'Merchant Payment Setup' : 'Payment Setup',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: _loading
          ? PageLoader(
              label: _isMerchant
                  ? 'Loading merchant payment setup...'
                  : 'Loading payment setup...',
            )
          : _buildBody(c),
    );
  }

  Widget _buildBody(AppColor c) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _loadAll,
        color: c.primary,
        backgroundColor: c.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            _StepHero(isMerchant: _isMerchant, c: c),
            const SizedBox(height: 28),

            _SectionLabel(
              label: _isMerchant ? 'ADD MERCHANT ACCOUNT' : 'ADD NEW ACCOUNT',
              c: c,
            ),
            const SizedBox(height: 10),

            _AccountForm(
              methods: _methods,
              selectedMethod: _selectedMethod,
              onMethodChanged: (m) => setState(() => _selectedMethod = m),
              accountNameCtrl: _accountNameCtrl,
              accountNoCtrl: _accountNoCtrl,
              labelCtrl: _labelCtrl,
              assetReceiverCtrl: _assetReceiverCtrl,
              instructionsCtrl: _isMerchant ? _instructionsCtrl : null,
              setAsActive: _setAsActive,
              saving: _saving,
              onSetAsActiveChanged: (v) => setState(() => _setAsActive = v),
              onSubmit: _createAccount,
              isMerchant: _isMerchant,
              c: c,
            ),

            const SizedBox(height: 28),

            _SectionLabel(
              label: _isMerchant ? 'YOUR MERCHANT ACCOUNTS' : 'YOUR ACCOUNTS',
              c: c,
            ),
            const SizedBox(height: 10),

            _accounts.isEmpty
                ? _EmptyCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No Accounts Yet',
                    body: 'Add your first payment account above.',
                    c: c,
                  )
                : _AccountList(
                    accounts: _accounts,
                    activeId: _activeAccountId,
                    settingActive: _settingActive,
                    onSetActive: _setActiveAccount,
                    onEdit: _editAccount,
                    onDelete: _deleteAccount,
                    c: c,
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED ACCOUNT ITEM
// Thin wrapper so the UI can stay independent from raw API models.
// ─────────────────────────────────────────────────────────────────────────────

class _AccountItem {
  final String id;
  final String accountName;
  final String? accountNo;
  final String? label;
  final String? assetReceiverAddress;
  final String? instructions;
  final bool isActive;
  final PaymentMethodModel? paymentMethod;

  const _AccountItem({
    required this.id,
    required this.accountName,
    this.accountNo,
    this.label,
    this.assetReceiverAddress,
    this.instructions,
    required this.isActive,
    this.paymentMethod,
  });

  factory _AccountItem.fromUser(UserPaymentAccountModel m) => _AccountItem(
    id: m.id,
    accountName: m.accountName,
    accountNo: m.accountNo,
    label: m.label,
    assetReceiverAddress: m.assetReceiverAddress,
    instructions: m.instructions,
    isActive: m.isActive,
    paymentMethod: m.paymentMethod,
  );

  /// Display subtitle parts
  String get subtitle {
    final methodName = paymentMethod?.name ?? '';
    final parts = [
      if (label != null && label!.isNotEmpty)
        label!
      else if (methodName.isNotEmpty)
        methodName,
      if (accountNo != null && accountNo!.isNotEmpty) accountNo!,
      if (assetReceiverAddress != null && assetReceiverAddress!.isNotEmpty)
        assetReceiverAddress!,
    ];
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP HERO
// ─────────────────────────────────────────────────────────────────────────────

class _StepHero extends StatelessWidget {
  const _StepHero({required this.isMerchant, required this.c});
  final bool isMerchant;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: c.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: c.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Account',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isMerchant
                      ? 'Step 2 of 2 · Add your settlement account'
                      : 'Step 2 of 3 · Link your preferred account',
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

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.c});
  final String label;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: c.textSecondary.withValues(alpha: 0.6),
        letterSpacing: 1.0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.c,
  });
  final IconData icon;
  final String title;
  final String body;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.border.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 17,
              color: c.textSecondary.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METHOD LOGO
// ─────────────────────────────────────────────────────────────────────────────

class _MethodLogo extends StatelessWidget {
  const _MethodLogo({
    required this.method,
    required this.size,
    required this.c,
  });
  final PaymentMethodModel method;
  final double size;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final logo = method.logo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: logo != null && logo.isNotEmpty
          ? Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: Image.network(
                logo,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _fallback(size),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Center(
                        child: SizedBox(
                          width: size * 0.38,
                          height: size * 0.38,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: c.primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
              ),
            )
          : _fallback(size),
    );
  }

  Widget _fallback(double size) => Center(
    child: Icon(
      Icons.account_balance_outlined,
      size: size * 0.52,
      color: c.primary,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// METHOD INFO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MethodInfoCard extends StatelessWidget {
  const _MethodInfoCard({required this.method, required this.c});
  final PaymentMethodModel method;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        method.description != null && method.description!.trim().isNotEmpty;
    final hasInstructions =
        method.instructions != null && method.instructions!.trim().isNotEmpty;
    if (!hasDescription && !hasInstructions) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: c.primary.withValues(alpha: 0.14),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MethodLogo(method: method, size: 32, c: c),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      method.code,
                      style: TextStyle(
                        color: c.primary.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasDescription) ...[
            const SizedBox(height: 10),
            _Divider(c: c),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.info_outline_rounded,
              label: 'ABOUT',
              text: method.description!,
              c: c,
            ),
          ],
          if (hasInstructions) ...[
            const SizedBox(height: 10),
            _Divider(c: c),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'INSTRUCTIONS',
              text: method.instructions!,
              c: c,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.c,
  });
  final IconData icon;
  final String label;
  final String text;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 13.5,
            color: c.primary.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    color: c.primary.withValues(alpha: 0.08),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// METHOD DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class _MethodDropdown extends StatelessWidget {
  const _MethodDropdown({
    required this.methods,
    required this.selected,
    required this.onChanged,
    required this.c,
  });
  final List<PaymentMethodModel> methods;
  final PaymentMethodModel? selected;
  final ValueChanged<PaymentMethodModel?> onChanged;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) {
      return _EmptyCard(
        icon: Icons.payment_outlined,
        title: 'No Payment Methods',
        body: 'No active payment methods are available right now.',
        c: c,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: c.border.withValues(alpha: 0.28),
              width: 1.2,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PaymentMethodModel>(
              value: selected,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: c.textSecondary,
                size: 20,
              ),
              dropdownColor: c.surface,
              borderRadius: BorderRadius.circular(13),
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              hint: Text(
                'Select payment method',
                style: TextStyle(
                  color: c.textSecondary.withValues(alpha: 0.5),
                  fontSize: 13.5,
                ),
              ),
              items: methods.map((m) {
                return DropdownMenuItem<PaymentMethodModel>(
                  value: m,
                  child: Row(
                    children: [
                      _MethodLogo(method: m, size: 28, c: c),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              m.code,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              selectedItemBuilder: (context) => methods.map((m) {
                return Row(
                  children: [
                    _MethodLogo(method: m, size: 26, c: c),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${m.name}  ·  ${m.code}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: selected != null
              ? _MethodInfoCard(method: selected!, c: c)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT FORM
// ─────────────────────────────────────────────────────────────────────────────

class _AccountForm extends StatelessWidget {
  const _AccountForm({
    required this.methods,
    required this.selectedMethod,
    required this.onMethodChanged,
    required this.accountNameCtrl,
    required this.accountNoCtrl,
    required this.labelCtrl,
    required this.assetReceiverCtrl,
    required this.instructionsCtrl, // null = hide field
    required this.setAsActive,
    required this.saving,
    required this.onSetAsActiveChanged,
    required this.onSubmit,
    required this.isMerchant,
    required this.c,
  });
  final List<PaymentMethodModel> methods;
  final PaymentMethodModel? selectedMethod;
  final ValueChanged<PaymentMethodModel?> onMethodChanged;
  final TextEditingController accountNameCtrl;
  final TextEditingController accountNoCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController assetReceiverCtrl;
  final TextEditingController? instructionsCtrl;
  final bool setAsActive;
  final bool saving;
  final ValueChanged<bool> onSetAsActiveChanged;
  final VoidCallback onSubmit;
  final bool isMerchant;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MethodDropdown(
          methods: methods,
          selected: selectedMethod,
          onChanged: onMethodChanged,
          c: c,
        ),
        const SizedBox(height: 10),
        _FocusField(
          controller: accountNameCtrl,
          label: 'Account Name',
          hint: 'e.g. Juan Dela Cruz',
          icon: Icons.person_outline_rounded,
          required: true,
          action: TextInputAction.next,
          c: c,
        ),
        const SizedBox(height: 10),
        _FocusField(
          controller: accountNoCtrl,
          label: 'Account Number',
          hint: 'Optional',
          icon: Icons.tag_rounded,
          action: TextInputAction.next,
          c: c,
        ),
        const SizedBox(height: 10),
        _FocusField(
          controller: labelCtrl,
          label: 'Label',
          hint: 'e.g. My GCash',
          icon: Icons.label_outline_rounded,
          action: instructionsCtrl != null
              ? TextInputAction.next
              : TextInputAction.done,
          c: c,
        ),
        const SizedBox(height: 10),
        _FocusField(
          controller: assetReceiverCtrl,
          label: 'Asset Receiver Address',
          hint: 'Optional Stellar address (G...)',
          icon: Icons.account_balance_wallet_outlined,
          action: instructionsCtrl != null
              ? TextInputAction.next
              : TextInputAction.done,
          c: c,
        ),
        if (instructionsCtrl != null) ...[
          const SizedBox(height: 10),
          _FocusField(
            controller: instructionsCtrl!,
            label: 'Instructions',
            hint: 'Optional payment instructions for buyers',
            icon: Icons.receipt_long_outlined,
            action: TextInputAction.done,
            multiline: true,
            c: c,
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: c.border.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set as active account',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Only one account can be active at a time',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: setAsActive,
                onChanged: onSetAsActiveChanged,
                activeColor: c.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CreateButton(
          saving: saving,
          onPressed: onSubmit,
          isMerchant: isMerchant,
          c: c,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT LIST
// ─────────────────────────────────────────────────────────────────────────────

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.activeId,
    required this.settingActive,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
    required this.c,
  });
  final List<_AccountItem> accounts;
  final String? activeId;
  final bool settingActive;
  final void Function(_AccountItem) onSetActive;
  final void Function(_AccountItem) onEdit;
  final void Function(_AccountItem) onDelete;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: accounts.map((a) {
        final isActive = a.isActive || activeId == a.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AccountTile(
            account: a,
            isActive: isActive,
            settingActive: settingActive,
            onSetActive: () => onSetActive(a),
            onEdit: () => onEdit(a),
            onDelete: () => onDelete(a),
            c: c,
          ),
        );
      }).toList(),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isActive,
    required this.settingActive,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
    required this.c,
  });
  final _AccountItem account;
  final bool isActive;
  final bool settingActive;
  final VoidCallback onSetActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: isActive ? c.primary.withValues(alpha: 0.04) : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? c.primary.withValues(alpha: 0.25)
              : c.border.withValues(alpha: 0.22),
          width: isActive ? 1.5 : 1.2,
        ),
      ),
      child: Row(
        children: [
          // Logo if method is known, otherwise status icon
          SizedBox(
            width: 36,
            height: 36,
            child: account.paymentMethod != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _MethodLogo(
                          method: account.paymentMethod!,
                          size: 36,
                          c: c,
                        ),
                      ),
                      if (isActive)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.background,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 8,
                              color: c.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isActive
                          ? c.primary.withValues(alpha: 0.1)
                          : c.border.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive
                          ? Icons.check_circle_outline_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isActive
                          ? c.primary
                          : c.textSecondary.withValues(alpha: 0.35),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.accountName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 18, color: c.textSecondary),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          const SizedBox(width: 6),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  color: c.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: settingActive ? null : onSetActive,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border.withValues(alpha: 0.2)),
                ),
                child: Text(
                  settingActive ? '…' : 'Set Active',
                  style: TextStyle(
                    color: settingActive
                        ? c.textSecondary.withValues(alpha: 0.3)
                        : c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOCUS FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _FocusField extends StatefulWidget {
  const _FocusField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.action,
    required this.c,
    this.required = false,
    this.multiline = false,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputAction action;
  final AppColor c;
  final bool required;
  final bool multiline;

  @override
  State<_FocusField> createState() => _FocusFieldState();
}

class _FocusFieldState extends State<_FocusField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final active = _focused;
    final activeBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.primary, width: 1.5),
    );
    final idleBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: c.border.withValues(alpha: 0.28),
        width: 1.2,
      ),
    );

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: TextFormField(
        controller: widget.controller,
        textInputAction: widget.action,
        minLines: widget.multiline ? 2 : 1,
        maxLines: widget.multiline ? 4 : 1,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: c.textSecondary.withValues(alpha: 0.4),
            fontSize: 13.5,
          ),
          labelStyle: TextStyle(
            color: active ? c.primary : c.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: active ? c.primary : c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              widget.icon,
              size: 17,
              color: active
                  ? c.primary
                  : c.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          filled: true,
          fillColor: active
              ? c.primary.withValues(alpha: 0.03)
              : c.border.withValues(alpha: 0.05),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: widget.multiline ? 14 : 0,
          ),
          border: idleBorder,
          enabledBorder: idleBorder,
          focusedBorder: activeBorder,
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
              color: c.error.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: c.error, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.saving,
    required this.onPressed,
    required this.isMerchant,
    required this.c,
  });
  final bool saving;
  final VoidCallback onPressed;
  final bool isMerchant;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: saving
            ? null
            : [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: AppElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.primary.withValues(alpha: 0.5),
          disabledForegroundColor: c.onPrimary,
          elevation: 0,
          shadowColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: saving
              ? Row(
                  key: const ValueKey('saving'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(c.onPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Creating…',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Create Payment Account',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSIONS
// ─────────────────────────────────────────────────────────────────────────────

extension _IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
