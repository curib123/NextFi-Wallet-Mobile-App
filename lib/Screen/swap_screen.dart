import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar_wallet_services.dart';
import 'package:next_fi/Components/AppAlert.dart';
class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key, this.testnet = false});
  final bool testnet;

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  late final StellarWalletService walletService;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _memoCtrl = TextEditingController();

  // ⬇️ Default slippage 5%
  final ValueNotifier<double> _slippage = ValueNotifier<double>(0.5);

  bool _busy = false;
  String? _accountId;
  String? _secretSeed;

  Map<String, double> _balances = {};
  Set<String> _trustlines = {};

  late final List<_AssetOption> _assets;
  late _AssetOption _sendAsset;
  late _AssetOption _receiveAsset;

  @override
  void initState() {
    super.initState();
    walletService = StellarWalletService(testnet: widget.testnet);

    const usdtIssuer = 'GA5ZSEK2S5M6X6NRV4WN7UDVEWGNWJMEVXWQ7GZL5I5MZN2TQWRVXQ4S';
    _assets = [
      _AssetOption(label: 'XLM', code: 'XLM', asset: Asset.NATIVE, icon: LucideIcons.layers),
      _AssetOption(
        label: 'USDT',
        code: 'USDT',
        asset: Asset.createNonNativeAsset('USDT', usdtIssuer),
        icon: LucideIcons.banknote,
      ),
      // add more assets here…
    ];

    _sendAsset = _assets.firstWhere((a) => a.code == 'XLM');
    _receiveAsset = _assets.firstWhere((a) => a.code == 'USDT');

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    try {
      final mnemonic = await SeedStorage.getSeed();
      if (mnemonic == null || mnemonic.isEmpty) {
        _toast("Wallet not found. Please create or import a wallet.");
        return;
      }
      final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);

      _accountId = kp.accountId;
      _secretSeed = kp.secretSeed;

      await _refreshBalancesAndTrustlines();
    } catch (e) {
      _toast('Failed to initialize swap: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshBalancesAndTrustlines() async {
    if (_accountId == null) return;
    try {
      final acc = await walletService.sdk.accounts.account(_accountId!);

      final tmpBalances = <String, double>{};
      final tmpTrust = <String>{};

      for (final b in acc.balances) {
        if (b.assetType == Asset.TYPE_NATIVE) {
          tmpBalances['XLM'] = double.tryParse(b.balance) ?? 0.0;
        } else {
          final code = b.assetCode ?? '';
          final issuer = b.assetIssuer ?? '';
          final id = '$code:$issuer';
          tmpBalances[id] = double.tryParse(b.balance) ?? 0.0;
          tmpTrust.add(id);
        }
      }

      setState(() {
        _balances = tmpBalances;
        _trustlines = tmpTrust;
      });
    } catch (_) {}
  }

  String _assetId(Asset asset) {
    if (asset.type == Asset.TYPE_NATIVE) return 'XLM';
    final a = asset as AssetTypeCreditAlphaNum;
    return '${a.code}:${a.issuerId}';
  }

  double _balanceOf(Asset asset) => _balances[_assetId(asset)] ?? 0.0;
  bool _hasTrustline(Asset asset) => asset.type == Asset.TYPE_NATIVE || _trustlines.contains(_assetId(asset));

  Future<void> _ensureTrustlineIfNeeded(Asset asset) async {
    if (asset.type == Asset.TYPE_NATIVE || _accountId == null || _secretSeed == null) return;
    final hasLine = await walletService.hasTrustline(_accountId!, asset);
    if (!hasLine) {
      await AppAlert.show(
        context: context,
        title: "Create Trustline",
        description:
        "No trustline for ${(asset as AssetTypeCreditAlphaNum).code}. We'll create one so you can receive it.",
        confirmText: "Continue",
        cancelText: "Cancel",
      );
      await walletService.createTrustLine(secretSeed: _secretSeed!, asset: asset);
      await _refreshBalancesAndTrustlines();
    }
  }

  Future<void> _onSwap() async {
    if (_accountId == null || _secretSeed == null) {
      _toast("Wallet not ready.");
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _toast("Enter a valid amount.");
      return;
    }
    if (_assetId(_sendAsset.asset) == _assetId(_receiveAsset.asset)) {
      _toast("Send and receive assets must be different.");
      return;
    }
    final bal = _balanceOf(_sendAsset.asset);
    if (amount > bal) {
      _toast("Insufficient ${_sendAsset.code} balance.");
      return;
    }

    try {
      setState(() => _busy = true);
      await _ensureTrustlineIfNeeded(_receiveAsset.asset);
    } catch (e) {
      setState(() => _busy = false);
      _toast("Failed to create trustline: $e");
      return;
    }

    final minReceive = amount * (1 - _slippage.value / 100);

    await AppAlert.show(
      context: context,
      title: "Confirm Swap",
      description:
      "From: ${_sendAsset.code}\n"
          "To: ${_receiveAsset.code}\n"
          "Send: ${amount.toStringAsFixed(7)} ${_sendAsset.code}\n"
          "Min receive (slip ${_slippage.value.toStringAsFixed(2)}%): "
          "${minReceive.toStringAsFixed(7)} ${_receiveAsset.code}\n\n"
          "${_memoCtrl.text.isNotEmpty ? "Memo: ${_memoCtrl.text}\n\n" : ""}"
          "Proceed?",
      confirmText: "Swap",
      cancelText: "Cancel",
    );

    try {
      final hash = await walletService.swap(
        secretSeed: _secretSeed!,
        sendAsset: _sendAsset.asset,
        receiveAsset: _receiveAsset.asset,
        sendAmount: amount,
        slippagePercent: _slippage.value, // ⬅️ uses 5% default
        memoText: _memoCtrl.text.isNotEmpty ? _memoCtrl.text : null,
      );

      await _refreshBalancesAndTrustlines();

      await AppAlert.show(
        context: context,
        title: "Swap Successful",
        description: "Submitted to Stellar.\n\nTransaction Hash:\n$hash",
        confirmText: "Close",
      );

      _amountCtrl.clear();
      _memoCtrl.clear();
    } catch (e) {
      await AppAlert.show(
        context: context,
        title: "Swap Failed",
        description: "We couldn’t complete your swap.\n\nDetails:\n$e",
        confirmText: "Close",
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        title: const Text("Swap", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBalancesAndTrustlines,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel("From (Send)", colors),
            const SizedBox(height: 8),
            _AssetPicker(
              assets: _assets, // ⬅️ no filtering
              selected: _sendAsset,
              colors: colors,
              onChanged: (a) {
                setState(() {
                  // ⬇️ If picking same as receive, auto-swap to keep them different
                  if (_assetId(a.asset) == _assetId(_receiveAsset.asset)) {
                    final prevFrom = _sendAsset;
                    _sendAsset = a;
                    _receiveAsset = prevFrom;
                  } else {
                    _sendAsset = a;
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            _BalanceRow(
              label: "Balance",
              value: _balanceOf(_sendAsset.asset),
              code: _sendAsset.code,
              colors: colors,
              busy: _busy,
              onRefresh: _busy ? null : _refreshBalancesAndTrustlines,
            ),
            const SizedBox(height: 16),

            _SectionLabel("To (Receive)", colors),
            const SizedBox(height: 8),
            _AssetPicker(
              assets: _assets, // ⬅️ no filtering
              selected: _receiveAsset,
              colors: colors,
              onChanged: (a) {
                setState(() {
                  if (_assetId(a.asset) == _assetId(_sendAsset.asset)) {
                    final prevTo = _receiveAsset;
                    _receiveAsset = a;
                    _sendAsset = prevTo;
                  } else {
                    _receiveAsset = a;
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            _TrustlineRow(
              hasTrust: _hasTrustline(_receiveAsset.asset),
              code: _receiveAsset.code,
              colors: colors,
            ),
            const SizedBox(height: 16),

            _SectionLabel("Amount to Swap", colors),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}')),
              ],
              decoration: InputDecoration(
                hintText: "0.0",
                suffixText: _sendAsset.code,
                prefixIcon: const Icon(Icons.currency_exchange),
                filled: true,
                fillColor: colors.surface.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [0.25, 0.5, 0.75, 1.0].map((pct) {
                return ActionChip(
                  label: Text("${(pct * 100).toInt()}%"),
                  onPressed: _busy
                      ? null
                      : () {
                    final bal = _balanceOf(_sendAsset.asset);
                    _amountCtrl.text = (bal * pct).toStringAsFixed(7);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            _SectionLabel("Slippage Tolerance", colors),
            const SizedBox(height: 4),
            ValueListenableBuilder<double>(
              valueListenable: _slippage,
              builder: (_, value, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ⬇️ Range widened; default is 5.0
                  Slider(
                    min: 0.1,
                    max: 10.0,
                    divisions: 99,
                    value: value,
                    onChanged: _busy ? null : (v) => _slippage.value = double.parse(v.toStringAsFixed(2)),
                  ),
                  Text("${value.toStringAsFixed(2)}%", style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _SectionLabel("Memo (optional)", colors),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              decoration: InputDecoration(
                hintText: "Enter memo…",
                prefixIcon: const Icon(Icons.note),
                filled: true,
                fillColor: colors.surface.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.arrowLeftRight),
                label: Text(_busy ? "Swapping…" : "Swap Now"),
                onPressed: _busy ? null : _onSwap,
              ),
            ),

            const SizedBox(height: 8),
            Text(
              "Tip: Pull down to refresh balances.",
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------ UI helpers (unchanged besides Balance refresh) ------------ */

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.colors);
  final String text;
  final AppColor colors;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 14),
  );
}

class _AssetPicker extends StatelessWidget {
  const _AssetPicker({
    required this.assets,
    required this.selected,
    required this.onChanged,
    required this.colors,
  });

  final List<_AssetOption> assets;
  final _AssetOption selected;
  final ValueChanged<_AssetOption> onChanged;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: colors.surface.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<_AssetOption>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down),
        items: assets
            .map((a) => DropdownMenuItem<_AssetOption>(
          value: a,
          child: Row(children: [Icon(a.icon, size: 18), const SizedBox(width: 8), Text(a.label)]),
        ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.value,
    required this.code,
    required this.colors,
    required this.busy,
    required this.onRefresh,
  });

  final String label;
  final double value;
  final String code;
  final AppColor colors;
  final bool busy;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("$label: ", style: TextStyle(color: colors.textSecondary)),
        if (busy)
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Text("${value.toStringAsFixed(7)} $code",
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          tooltip: "Refresh",
          onPressed: busy || onRefresh == null ? null : () => onRefresh!(),
          icon: Icon(LucideIcons.refreshCcw, color: colors.textSecondary, size: 18),
        ),
      ],
    );
  }
}

class _TrustlineRow extends StatelessWidget {
  const _TrustlineRow({required this.hasTrust, required this.code, required this.colors});
  final bool hasTrust;
  final String code;
  final AppColor colors;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(hasTrust ? Icons.verified : Icons.error_outline, size: 16, color: hasTrust ? colors.success : colors.error),
        const SizedBox(width: 6),
        Text(hasTrust ? "Trustline exists for $code" : "No trustline for $code",
            style: TextStyle(color: hasTrust ? colors.textSecondary : colors.error)),
      ],
    );
  }
}

class _AssetOption {
  final String label;
  final String code;
  final Asset asset;
  final IconData icon;
  _AssetOption({required this.label, required this.code, required this.asset, required this.icon});
}
