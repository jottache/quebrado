import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/currency_type.dart';

class CommaTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(',', '.');
    return newValue.copyWith(
        text: newText,
        selection: newValue.selection.copyWith(
          baseOffset: newValue.selection.baseOffset,
          extentOffset: newValue.selection.extentOffset,
        ));
  }
}

Color parseHexColor(String hex) {
  var hexStr = hex.replaceAll('#', '');
  if (hexStr.length == 6) {
    hexStr = 'FF$hexStr';
  }
  return Color(int.parse(hexStr, radix: 16));
}

String formatUSD(double amount) {
  return "\$${amount.toStringAsFixed(2)}";
}

String formatCurrency(double amount, CurrencyType type) {
  if (type == CurrencyType.usd) {
    return formatUSD(amount);
  } else if (type == CurrencyType.eur) {
    return "€${amount.toStringAsFixed(2)}";
  } else {
    return formatBs(amount);
  }
}

String formatBs(double amount) {
  return "Bs. ${amount.toStringAsFixed(2)}";
}

String formatRate(double rate) {
  return "Bs. ${rate.toStringAsFixed(2)}";
}

String formatDate(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
}

String formatFullDate(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return "${formatDate(date)} $hour:$minute";
}

IconData getIconData(String iconName) {
  final cleanName = iconName.replaceAll('.fill', '').replaceAll('_', '').toLowerCase();
  
  switch (cleanName) {
    case 'shield':
      return Icons.shield;
    case 'house':
    case 'home':
      return Icons.home;
    case 'iphone':
      return Icons.phone_iphone;
    case 'cart':
      return Icons.shopping_cart;
    case 'car':
      return Icons.directions_car;
    case 'star':
      return Icons.star;
    case 'airplane':
    case 'flight':
      return Icons.flight;
    case 'heart':
    case 'favorite':
      return Icons.favorite;
    case 'creditcard':
      return Icons.credit_card;
    case 'tv':
      return Icons.tv;
    case 'music.note':
    case 'musicnote':
      return Icons.music_note;
    case 'bolt':
    case 'flash':
      return Icons.flash_on;
    case 'wifi':
      return Icons.wifi;
    case 'gamecontroller':
      return Icons.sports_esports;
    case 'person':
      return Icons.person;
    case 'briefcase':
    case 'work':
      return Icons.work;
    case 'laptopcomputer':
    case 'computer':
      return Icons.computer;
    case 'gift':
      return Icons.card_giftcard;
    case 'chart.line.uptrend.xyaxis':
    case 'chartlineuptrend':
    case 'trendingup':
      return Icons.trending_up;
    case 'ellipsis.circle':
    case 'ellipsis':
      return Icons.more_horiz;
    case 'fork.knife':
    case 'restaurant':
      return Icons.restaurant;
    case 'cup.and.saucer':
    case 'localcafe':
      return Icons.local_cafe;
    case 'bag':
      return Icons.local_mall;
    case 'medical.tab':
    case 'medical':
      return Icons.medical_services;
    case 'pills':
      return Icons.medication;
    case 'tag':
      return Icons.local_offer;
    case 'wallet.pass':
    case 'wallet':
      return Icons.account_balance_wallet;
    case 'clock':
      return Icons.access_time_filled;
    case 'gearshape':
    case 'gear':
      return Icons.settings;
    case 'plusminus.circle':
    case 'calculator':
      return Icons.calculate_outlined;
    case 'bank':
      return Icons.account_balance;
    case 'book':
      return Icons.book;
    default:
      return Icons.help_outline;
  }
}
