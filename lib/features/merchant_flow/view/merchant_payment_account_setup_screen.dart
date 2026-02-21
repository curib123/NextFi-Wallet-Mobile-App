import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/verification_result_modal.dart';
import 'package:next_fi/services/merchant_payment_account/merchant_payment_account_core_service.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_dtos.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';

class MerchantPaymentAccountSetupScreen extends StatefulWidget {
  const MerchantPaymentAccountSetupScreen({super.key});

  @override
  State<MerchantPaymentAccountSetupScreen> createState() =>
      _MerchantPaymentAccountSetupScreenState();
}

class _MerchantPaymentAccountSetupScreenState
    extends State<MerchantPaymentAccountSetupScreen>
    with SingleTickerProviderStateMixin {
  final _merchantCore = MerchantPaymentAccountCoreService.I;
  final _paymentCore = PaymentMethodAndAccountsCoreService.I;

  final _accountNameCtrl = TextEditingController();
  final _accountNoCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _settingActive = false;
  bool _setAsActive = true;

  List<PaymentMethodModel> _methods = const [];
  List<MerchantPaymentAccountModel> _accounts = const [];
  PaymentMethodModel? _selectedMethod;
  String? _activeAccountId;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

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
    _instructionsCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final methods = await _paymentCore.listPaymentMethods(activeOnly: true);
      final accounts = await _merchantCore.listAll();
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
      _showSnack('Failed to load merchant payment setup: $e');
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
      final req = CreateMerchantPaymentAccountRequest(
        paymentMethodId: method.id,
        accountName: accountName,
        accountNo: _accountNoCtrl.text.trim().isEmpty
            ? null
            : _accountNoCtrl.text.trim(),
        label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        instructions: _instructionsCtrl.text.trim().isEmpty
            ? null
            : _instructionsCtrl.text.trim(),
        isActive: _setAsActive,
      );
      await _merchantCore.create(req);
      _accountNameCtrl.clear();
      _accountNoCtrl.clear();
      _labelCtrl.clear();
      _instructionsCtrl.clear();
      if (!mounted) return;
      await _loadAll();
      if (!mounted) return;
      await showVerificationResultModal(
        context,
        title: 'Merchant Account Added',
        message: 'Your merchant payment account has been created.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  Future<void> _setActiveAccount(MerchantPaymentAccountModel account) async {
    if (_settingActive || account.isActive) return;
    HapticFeedback.lightImpact();
    setState(() => _settingActive = true);
    try {
      await _merchantCore.update(
        account.id,
        const UpdateMerchantPaymentAccountRequest(isActive: true),
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

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
          'Merchant Payment Setup',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _loading ? _buildLoader() : _buildBody(c),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(),
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
            _StepHero(c: c),
            const SizedBox(height: 24),
            _SectionLabel(label: 'SELECT METHOD', c: c),
            const SizedBox(height: 10),
            _methods.isEmpty
                ? _EmptyCard(
                    icon: Icons.payment_outlined,
                    title: 'No Payment Methods',
                    body: 'No active payment methods are available right now.',
                    c: c,
                  )
                : _MethodGrid(
                    methods: _methods,
                    selected: _selectedMethod,
                    onSelect: (m) => setState(() => _selectedMethod = m),
                    c: c,
                  ),
            const SizedBox(height: 28),
            _SectionLabel(label: 'ADD MERCHANT ACCOUNT', c: c),
            const SizedBox(height: 10),
            _AccountForm(
              accountNameCtrl: _accountNameCtrl,
              accountNoCtrl: _accountNoCtrl,
              labelCtrl: _labelCtrl,
              instructionsCtrl: _instructionsCtrl,
              setAsActive: _setAsActive,
              saving: _saving,
              onSetAsActiveChanged: (v) => setState(() => _setAsActive = v),
              onSubmit: _createAccount,
              c: c,
            ),
            const SizedBox(height: 28),
            _SectionLabel(label: 'YOUR MERCHANT ACCOUNTS', c: c),
            const SizedBox(height: 10),
            _accounts.isEmpty
                ? _EmptyCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No Accounts Yet',
                    body: 'Add your first merchant payment account above.',
                    c: c,
                  )
                : _AccountList(
                    accounts: _accounts,
                    activeId: _activeAccountId,
                    settingActive: _settingActive,
                    onSetActive: _setActiveAccount,
                    c: c,
                  ),
          ],
        ),
      ),
    );
  }
}

class _StepHero extends StatelessWidget {
  const _StepHero({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              shape: BoxShape.circle,
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
                  'Merchant Payment Account',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Step 2 of 2 · Add your settlement account',
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
        color: c.textSecondary.withOpacity(0.6),
        letterSpacing: 1.0,
      ),
    );
  }
}

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
        border: Border.all(color: c.border.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.border.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: c.textSecondary.withOpacity(0.45)),
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

class _MethodGrid extends StatelessWidget {
  const _MethodGrid({
    required this.methods,
    required this.selected,
    required this.onSelect,
    required this.c,
  });
  final List<PaymentMethodModel> methods;
  final PaymentMethodModel? selected;
  final ValueChanged<PaymentMethodModel> onSelect;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: methods.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final m = methods[i];
        final isSelected = selected?.id == m.id;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(m),
            borderRadius: BorderRadius.circular(14),
            splashColor: c.primary.withOpacity(0.07),
            child: Ink(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isSelected ? c.primary.withOpacity(0.06) : c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? c.primary : c.border.withOpacity(0.25),
                  width: isSelected ? 1.5 : 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? c.primary.withOpacity(0.12)
                              : c.border.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.account_balance_outlined,
                          size: 14,
                          color: isSelected ? c.primary : c.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: c.primary,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.code,
                    style: TextStyle(
                      color: isSelected
                          ? c.primary.withOpacity(0.8)
                          : c.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountForm extends StatelessWidget {
  const _AccountForm({
    required this.accountNameCtrl,
    required this.accountNoCtrl,
    required this.labelCtrl,
    required this.instructionsCtrl,
    required this.setAsActive,
    required this.saving,
    required this.onSetAsActiveChanged,
    required this.onSubmit,
    required this.c,
  });
  final TextEditingController accountNameCtrl;
  final TextEditingController accountNoCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController instructionsCtrl;
  final bool setAsActive;
  final bool saving;
  final ValueChanged<bool> onSetAsActiveChanged;
  final VoidCallback onSubmit;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(c: c, controller: accountNameCtrl, label: 'Account Name *'),
        const SizedBox(height: 10),
        _Field(c: c, controller: accountNoCtrl, label: 'Account Number'),
        const SizedBox(height: 10),
        _Field(c: c, controller: labelCtrl, label: 'Label'),
        const SizedBox(height: 10),
        _Field(
          c: c,
          controller: instructionsCtrl,
          label: 'Instructions',
          multiline: true,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: c.border.withOpacity(0.22)),
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
        SizedBox(
          height: 52,
          child: AppElevatedButton(
            onPressed: saving ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: c.primary.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  )
                : const Text(
                    'Create Merchant Account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.activeId,
    required this.settingActive,
    required this.onSetActive,
    required this.c,
  });
  final List<MerchantPaymentAccountModel> accounts;
  final String? activeId;
  final bool settingActive;
  final void Function(MerchantPaymentAccountModel) onSetActive;
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
    required this.c,
  });
  final MerchantPaymentAccountModel account;
  final bool isActive;
  final bool settingActive;
  final VoidCallback onSetActive;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final paymentMethodName = account.paymentMethod?['name']?.toString() ?? 'Unknown';
    final parts = [
      account.label ?? paymentMethodName,
      if (account.accountNo != null) account.accountNo!,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: isActive ? c.primary.withOpacity(0.04) : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? c.primary.withOpacity(0.25) : c.border.withOpacity(0.22),
          width: isActive ? 1.5 : 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? c.primary.withOpacity(0.1) : c.border.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isActive ? c.primary : c.textSecondary.withOpacity(0.35),
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
                  parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.1),
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
                  color: c.border.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border.withOpacity(0.2)),
                ),
                child: Text(
                  settingActive ? '…' : 'Set Active',
                  style: TextStyle(
                    color: settingActive
                        ? c.textSecondary.withOpacity(0.3)
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

class _Field extends StatelessWidget {
  const _Field({
    required this.c,
    required this.controller,
    required this.label,
    this.multiline = false,
  });
  final AppColor c;
  final TextEditingController controller;
  final String label;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: c.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: c.border.withOpacity(0.05),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: multiline ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.28), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.28), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
