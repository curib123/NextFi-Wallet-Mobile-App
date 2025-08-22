import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Model/ChainModel.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Services/coingecko_services.dart';
import 'package:next_fi/Services/tron_wallet_services.dart';
import 'package:provider/provider.dart';

Widget actionButton(AppColor colors, IconData icon, String label) {
  return Column(
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: colors.primary.withOpacity(0.9),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(color: colors.textPrimary)),
    ],
  );
}

Widget chainTile({
  required AppColor colors,
  required ChainData chain, // Now directly takes model
}) {
  final numberFormatter = NumberFormat("#,##0.00", "en_US");

  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Image.network(
      chain.logoUrl,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) =>
      const Icon(Icons.error, size: 24),
    ),
    title: Text(
      chain.title,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
    ),
    trailing: Text(
      numberFormatter.format(chain.amount),
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.bold,

      ),
    ),
  );
}

Future<List<Map<String, dynamic>>> _fetchChainData(String address) async {
  final List<Map<String, dynamic>> tokens = [];

  // Helper to get price from CoinGecko API
  Future<double> _getPrice(String id) async {
    try {
      final url = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=$id&vs_currencies=usd',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return (data[id]?['usd'] ?? 0).toDouble();
      }
    } catch (e) {
      debugPrint("Error fetching $id price: $e");
    }
    return 0.0;
  }

  // 🔹 USDT FIRST
  try {
    final usdtImage = await CoinGeckoService.getUsdtImage();
    double usdtBalance = 0;
    try {
      usdtBalance = await TronWalletService.getUsdtBalance(address);
    } catch (e) {
      debugPrint("Error fetching USDT balance for $address: $e");
    }
    final usdtPrice = await _getPrice('tether');
    tokens.add({
      'id': 'tether',
      'symbol': 'USDT',
      'image': usdtImage,
      'balance': usdtBalance,
      'price': usdtPrice,
    });
  } catch (e) {
    debugPrint("Error fetching USDT image for $address: $e");
    tokens.add({
      'id': 'tether',
      'symbol': 'USDT',
      'image': null,
      'balance': 0.0,
      'price': 0.0,
    });
  }

  // 🔹 Then TRX
  try {
    final trxImage = await CoinGeckoService.getTrxImage();
    double trxBalance = 0;
    try {
      final trxSun = await TronWalletService.getTrxBalance(address);
      trxBalance = trxSun / 1e6;
    } catch (e) {
      debugPrint("Error fetching TRX balance for $address: $e");
    }
    final trxPrice = await _getPrice('tron');
    tokens.add({
      'id': 'tron',
      'symbol': 'TRX',
      'image': trxImage,
      'balance': trxBalance,
      'price': trxPrice,
    });
  } catch (e) {
    debugPrint("Error fetching TRX image for $address: $e");
    tokens.add({
      'id': 'tron',
      'symbol': 'TRX',
      'image': null,
      'balance': 0.0,
      'price': 0.0,
    });
  }

  return tokens;
}


Widget chainListView(AppColor colors, String address) {
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: _fetchChainData(address),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Center(child: Text("No tokens found"));
      }

      final tokens = snapshot.data!;
      final currency = Provider.of<CurrencyProvider>(context);

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: tokens.length,
        separatorBuilder: (_, __) => Divider(thickness: 0.5),
        itemBuilder: (context, index) {
          final data = tokens[index];
          final double balance = data['balance'] ?? 0.0;
          final double price = data['price'] ?? 0.0; // USD price
          final double totalValueUsd = balance * price;

          // Convert total value → fiat
          final double totalValueFiat = currency.convert(totalValueUsd);

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.network(
                data['image'] ?? '',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => CircleAvatar(
                  backgroundColor: colors.primary.withOpacity(0.1),
                  child: Icon(Icons.monetization_on,
                      color: colors.primary, size: 20),
                ),
              ),
            ),
            title: Row(
              children: [
                 Text(
                  "${balance.toStringAsFixed(4)}",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
               SizedBox(width: 10,),
                Text(
                  data['symbol'] ?? 'Unknown',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Price: \$${price.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "\$${totalValueUsd.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (!currency.loading)
                  Text(
                    "${totalValueFiat.toStringAsFixed(2)} ${currency.fiat.toUpperCase()}",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}


Widget recipientList(AppColor colors) {
  return ListView.builder(
    itemCount: 10,
    itemBuilder: (context, index) {
      return recipientTile(
        colors: colors,
        recipientName: 'Recipient #$index',
        address: '0xABCDEF12345$index',
        onTap: () {
          // Handle tap event
        },
      );
    },
  );
}

Widget recipientTile({
  required AppColor colors,
  required String recipientName,
  required String address,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: colors.surface.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.primary.withOpacity(0.1),
        child: Icon(LucideIcons.user, color: colors.primary),
      ),
      title: Text(
        recipientName,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        address,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Icon(LucideIcons.chevronRight, color: colors.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}