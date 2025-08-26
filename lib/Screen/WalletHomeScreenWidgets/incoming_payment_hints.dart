import 'package:flutter/material.dart';

/// Tron transaction hint widget
/// [tx] should be a parsed transaction map from TronGrid/WebSocket
/// [address] is the user’s own wallet address (so we know if incoming)
Widget incomingPaymentHint(Map<String, dynamic> tx, String address) {
  final ret = tx['ret']?[0]?['contractRet'] ?? 'UNKNOWN';
  final isCompleted = ret == 'SUCCESS';

  final contract = tx['raw_data']?['contract']?[0];
  final type = contract?['type'] ?? '';
  final value = contract?['parameter']?['value'] ?? {};

  String from = value['owner_address'] ?? '';
  String to = value['to_address'] ?? '';
  String token = 'TRX';
  String amount = '';

  // Handle TRX (TransferContract)
  if (type == 'TransferContract') {
    final rawAmt = value['amount'] ?? 0;
    amount = (rawAmt / 1e6).toStringAsFixed(6); // TRX uses 6 decimals
  }

  // Handle TRC20 (TriggerSmartContract, e.g. USDT)
  if (type == 'TriggerSmartContract') {
    token = 'USDT'; // you can decode actual contract if needed
    final param = value['data']; // hex encoded transfer
    // You’d parse hex “a9059cbb” → transfer(to,amount)
    // For now, just show generic
    amount = '??';
  }

  final isIncoming = to == address;

  return GestureDetector(
    onTap: () {
      // TODO: handle click (open tx details)
    },
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.yellow[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Icon indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.green : Colors.yellow[700],
            ),
          ),
          const SizedBox(width: 10),
          // Payment info
          Expanded(
            child: Text(
              isIncoming
                  ? 'Incoming $amount $token from $from'
                  : 'Outgoing $amount $token to $to',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status label
          Text(
            isCompleted ? 'Completed' : 'Pending',
            style: TextStyle(
              color: isCompleted ? Colors.green : Colors.yellow[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
