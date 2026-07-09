import 'package:uuid/uuid.dart';

class ExchangeRateRecord {
  final String id;
  final DateTime date;
  final double rate;

  ExchangeRateRecord({
    required this.id,
    required this.date,
    required this.rate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'rate': rate,
    };
  }

  factory ExchangeRateRecord.fromMap(Map<String, dynamic> map) {
    return ExchangeRateRecord(
      id: map['id'] ?? const Uuid().v4(),
      date: map['date'] is String ? DateTime.parse(map['date']) : DateTime.fromMillisecondsSinceEpoch(map['date']),
      rate: (map['rate'] as num).toDouble(),
    );
  }
}
