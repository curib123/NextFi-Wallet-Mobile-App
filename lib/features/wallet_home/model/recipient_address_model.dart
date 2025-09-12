import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class RecipientAddressModel {
  final String id;
  final String name;
  final String address;
  final int color;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipientAddressModel({
    required this.id,
    required this.name,
    required this.address,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  RecipientAddressModel copyWith({
    String? id,
    String? name,
    String? address,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecipientAddressModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static RecipientAddressModel fromJson(Map<String, dynamic> m) => RecipientAddressModel(
    id: m['id'],
    name: m['name'],
    address: m['address'],
    color: m['color'],
    createdAt: DateTime.parse(m['createdAt']),
    updatedAt: DateTime.parse(m['updatedAt']),
  );

  static String encodeList(List<RecipientAddressModel> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<RecipientAddressModel> decodeList(String? s) {
    if (s == null || s.isEmpty) return [];
    final raw = jsonDecode(s) as List;
    return raw.map((e) => RecipientAddressModel.fromJson(e)).toList();
  }
}
