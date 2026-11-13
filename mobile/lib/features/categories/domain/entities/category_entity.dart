import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.colorHex,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String type; // 'EXPENSE' | 'INCOME'
  final String icon;
  final String colorHex;
  final bool isSystem;

  factory CategoryEntity.fromJson(Map<String, dynamic> json) {
    return CategoryEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: (json['icon'] as String?) ?? 'category',
      colorHex: (json['colorHex'] as String?) ?? '#4F46E5',
      isSystem: (json['isSystem'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'colorHex': colorHex,
        'isSystem': isSystem,
      };

  Color get color {
    final cleaned = colorHex.replaceFirst('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF4F46E5;
    return Color(value);
  }

  IconData get iconData {
    switch (icon) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'subscriptions':
        return Icons.subscriptions_rounded;
      case 'local_grocery_store':
        return Icons.local_grocery_store_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'laptop_mac':
        return Icons.laptop_mac_rounded;
      case 'storefront':
        return Icons.storefront_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  List<Object?> get props => [id, name, type, icon, colorHex, isSystem];
}
