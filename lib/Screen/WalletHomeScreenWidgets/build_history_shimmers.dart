import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Widget buildHistoryShimmer() {
  return ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(height: 14),
    itemBuilder: (context, index) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 80,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(height: 16, width: 120, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 14, width: 80, color: Colors.white),
                  ],
                ),
              ),
              Container(height: 16, width: 60, color: Colors.white),
            ],
          ),
        ),
      );
    },
  );
}
