import 'package:flutter/material.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

Widget incomingPaymentHint(PaymentOperationResponse payment) {
  final bool isCompleted = payment.transactionSuccessful;

  return GestureDetector(
    onTap: () {
      // Empty click function for now
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
              'Incoming ${payment.amount} ${payment.assetCode ?? 'XLM'} from ${payment.from}',
              style: TextStyle(
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