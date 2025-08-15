import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Model/ChainModel.dart';
import 'package:next_fi/Provider/ChainProvider.dart';
import 'package:provider/provider.dart' show Consumer;

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

Widget chainListView(AppColor colors) {

  return Consumer<ChainProvider>(
    builder: (context, chainProvider, _) {
      if (chainProvider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (chainProvider.chains.isEmpty) {
        return const Center(child: Text('No chains available'));
      }

      return ListView(
        children: chainProvider.chains.map((chain) {
          return chainTile(
            colors: colors,
            chain: chain, // Using your updated model-based widget
          );
        }).toList(),
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