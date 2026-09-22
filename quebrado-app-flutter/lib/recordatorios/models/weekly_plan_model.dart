import 'package:intl/intl.dart';

class WeeklyPlanModel {
  final String id;
  final String userId;
  final DateTime weekStartDate; // Normalized to Monday midnight
  final String? reflectionNotes;
  final String status; // 'active', 'archived'
  final DateTime createdAt;

  const WeeklyPlanModel({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    this.reflectionNotes,
    this.status = 'active',
    required this.createdAt,
  });

  /// Normaliza cualquier fecha dada al lunes correspondiente a las 00:00:00.
  static DateTime normalizeToMonday(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    // En Dart: Monday = 1, Sunday = 7
    final difference = clean.weekday - DateTime.monday;
    return clean.subtract(Duration(days: difference));
  }

  /// Domingo que cierra la semana del plan.
  DateTime get weekEndDate => weekStartDate.add(const Duration(days: 6));

  /// Determina si este plan corresponde a la semana actual.
  bool get isCurrentWeek {
    final currentMonday = normalizeToMonday(DateTime.now());
    return weekStartDate.year == currentMonday.year &&
        weekStartDate.month == currentMonday.month &&
        weekStartDate.day == currentMonday.day;
  }

  /// Retorna un rango legible en español, ej. "22 Sep - 28 Sep"
  String get formattedRange {
    try {
      final startStr = DateFormat('d MMM', 'es').format(weekStartDate);
      final endStr = DateFormat('d MMM', 'es').format(weekEndDate);
      return '$startStr - $endStr';
    } catch (_) {
      const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final startStr = '${weekStartDate.day} ${months[weekStartDate.month - 1]}';
      final endStr = '${weekEndDate.day} ${months[weekEndDate.month - 1]}';
      return '$startStr - $endStr';
    }
  }

  factory WeeklyPlanModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedStartDate;
    if (map['week_start_date'] is DateTime) {
      parsedStartDate = map['week_start_date'] as DateTime;
    } else {
      parsedStartDate = DateTime.parse(map['week_start_date'] as String);
    }

    DateTime parsedCreatedAt;
    if (map['created_at'] != null) {
      if (map['created_at'] is DateTime) {
        parsedCreatedAt = map['created_at'] as DateTime;
      } else {
        parsedCreatedAt = DateTime.parse(map['created_at'] as String);
      }
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return WeeklyPlanModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      weekStartDate: normalizeToMonday(parsedStartDate),
      reflectionNotes: map['reflection_notes'] as String?,
      status: map['status']?.toString() ?? 'active',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'week_start_date': DateFormat('yyyy-MM-dd').format(weekStartDate),
      'reflection_notes': reflectionNotes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  WeeklyPlanModel copyWith({
    String? id,
    String? userId,
    DateTime? weekStartDate,
    String? reflectionNotes,
    String? status,
    DateTime? createdAt,
  }) {
    return WeeklyPlanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      weekStartDate: weekStartDate != null
          ? normalizeToMonday(weekStartDate)
          : this.weekStartDate,
      reflectionNotes: reflectionNotes ?? this.reflectionNotes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'WeeklyPlanModel(id: $id, week: $formattedRange, status: $status)';
}
