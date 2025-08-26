import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:next_fi/Screen/qr_code_scanner.dart';
import 'package:provider/provider.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Components/SnackBar.dart';

class SendScreen extends StatefulWidget {
  final String address; // User's own address
  final String token;   // TRX or USDT
  final double balance;
  final bool autoOpenScanner; // New flag

  const SendScreen({
    super.key,
    required this.address,
    required this.token,
    required this.balance,
    this.autoOpenScanner = false, // default false
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanQRCode());
    }
  }

  void _sendToken() {
    if (!_formKey.currentState!.validate()) return;

    final recipient = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amount <= 0 || amount > widget.balance) {
      showFloatingSnackBar(
        context,
        message: "Invalid amount",
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isSending = true);

    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSending = false);
      showFloatingSnackBar(
        context,
        message: "$amount ${widget.token} sent to $recipient",
        type: SnackBarType.success,
      );
      Navigator.pop(context);
    });
  }

  Future<void> _scanQRCode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (code != null) {
      _recipientController.text = code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context);

    final priceHistory = (widget.token == "TRX")
        ? currency.trxHistory
        : currency.usdtHistory;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Send ${widget.token}",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ===== Realtime Price Display =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "1 ${widget.token} ≈ ${NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase()).format(
                      (widget.token == "TRX")
                          ? currency.trxToFiat(1)
                          : currency.usdtToFiat(1)
                  )}",
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===== Balance Card =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  "${NumberFormat("#,##0.00").format(widget.balance)} ${widget.token}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "≈ ${NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase()).format(
                      (widget.token == "TRX")
                          ? currency.trxToFiat(widget.balance)
                          : currency.usdtToFiat(widget.balance)
                  )}",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),

              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===== Price Chart =====
          Container(
            height: 150,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withOpacity(0.1)),
            ),
            child: priceHistory.isEmpty
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    spots: [
                      for (int i = 0; i < priceHistory.length; i++)
                        FlSpot(i.toDouble(), priceHistory[i]),
                    ],
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.primary.withOpacity(0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [colors.primary.withOpacity(0.2), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(show: false),
                    barWidth: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ===== Form =====
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    labelText: "Recipient Address",
                    prefixIcon: Icon(LucideIcons.user, color: colors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(LucideIcons.qrCode, color: colors.primary),
                      onPressed: _scanQRCode,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter recipient address" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Amount",
                    prefixIcon: Icon(LucideIcons.coins, color: colors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter amount" : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===== Send Button =====
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendToken,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                "Send ${widget.token}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
