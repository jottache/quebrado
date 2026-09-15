import 'package:flutter/material.dart';
import '../theme/reminders_colors.dart';

enum ReminderPriority {
  p1Urgent,
  p2High,
  p3Medium,
  p4Low;

  String get code {
    switch (this) {
      case ReminderPriority.p1Urgent:
        return 'p1_urgent';
      case ReminderPriority.p2High:
        return 'p2_high';
      case ReminderPriority.p3Medium:
        return 'p3_medium';
      case ReminderPriority.p4Low:
        return 'p4_low';
    }
  }

  String get label {
    switch (this) {
      case ReminderPriority.p1Urgent:
        return 'P1 Urgente';
      case ReminderPriority.p2High:
        return 'P2 Alta';
      case ReminderPriority.p3Medium:
        return 'P3 Media';
      case ReminderPriority.p4Low:
        return 'P4 Baja';
    }
  }

  Color get color {
    switch (this) {
      case ReminderPriority.p1Urgent:
        return RemindersColors.urgent;
      case ReminderPriority.p2High:
        return RemindersColors.high;
      case ReminderPriority.p3Medium:
        return RemindersColors.medium;
      case ReminderPriority.p4Low:
        return RemindersColors.low;
    }
  }

  static ReminderPriority fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'p1_urgent':
      case 'p1':
      case 'urgent':
      case 'urgente':
        return ReminderPriority.p1Urgent;
      case 'p2_high':
      case 'p2':
      case 'high':
      case 'alta':
        return ReminderPriority.p2High;
      case 'p4_low':
      case 'p4':
      case 'low':
      case 'baja':
        return ReminderPriority.p4Low;
      case 'p3_medium':
      case 'p3':
      case 'medium':
      case 'media':
      default:
        return ReminderPriority.p3Medium;
    }
  }
}

enum ReminderStatus {
  pending,
  completed,
  snoozed,
  archived;

  String get code {
    switch (this) {
      case ReminderStatus.pending:
        return 'pending';
      case ReminderStatus.completed:
        return 'completed';
      case ReminderStatus.snoozed:
        return 'snoozed';
      case ReminderStatus.archived:
        return 'archived';
    }
  }

  String get label {
    switch (this) {
      case ReminderStatus.pending:
        return 'Pendiente';
      case ReminderStatus.completed:
        return 'Completado';
      case ReminderStatus.snoozed:
        return 'Pospuesto';
      case ReminderStatus.archived:
        return 'Archivado';
    }
  }

  static ReminderStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'completed':
        return ReminderStatus.completed;
      case 'snoozed':
        return ReminderStatus.snoozed;
      case 'archived':
        return ReminderStatus.archived;
      case 'pending':
      default:
        return ReminderStatus.pending;
    }
  }
}

enum ReminderRecurrence {
  none,
  daily,
  weekly,
  biweekly,
  monthly,
  yearly;

  String get code {
    switch (this) {
      case ReminderRecurrence.none:
        return 'none';
      case ReminderRecurrence.daily:
        return 'daily';
      case ReminderRecurrence.weekly:
        return 'weekly';
      case ReminderRecurrence.biweekly:
        return 'biweekly';
      case ReminderRecurrence.monthly:
        return 'monthly';
      case ReminderRecurrence.yearly:
        return 'yearly';
    }
  }

  String get label {
    switch (this) {
      case ReminderRecurrence.none:
        return 'No se repite';
      case ReminderRecurrence.daily:
        return 'Diario';
      case ReminderRecurrence.weekly:
        return 'Semanal';
      case ReminderRecurrence.biweekly:
        return 'Quincenal (cada 15 días)';
      case ReminderRecurrence.monthly:
        return 'Mensual';
      case ReminderRecurrence.yearly:
        return 'Anual';
    }
  }

  String get shortLabel {
    switch (this) {
      case ReminderRecurrence.none:
        return '';
      case ReminderRecurrence.daily:
        return 'Diario';
      case ReminderRecurrence.weekly:
        return 'Semanal';
      case ReminderRecurrence.biweekly:
        return 'Quincenal';
      case ReminderRecurrence.monthly:
        return 'Mensual';
      case ReminderRecurrence.yearly:
        return 'Anual';
    }
  }

  String? get rruleString {
    switch (this) {
      case ReminderRecurrence.none:
        return null;
      case ReminderRecurrence.daily:
        return 'FREQ=DAILY';
      case ReminderRecurrence.weekly:
        return 'FREQ=WEEKLY';
      case ReminderRecurrence.biweekly:
        return 'FREQ=WEEKLY;INTERVAL=2';
      case ReminderRecurrence.monthly:
        return 'FREQ=MONTHLY';
      case ReminderRecurrence.yearly:
        return 'FREQ=YEARLY';
    }
  }

  static ReminderRecurrence fromRrule(String? rrule) {
    if (rrule == null || rrule.trim().isEmpty) return ReminderRecurrence.none;
    final upper = rrule.toUpperCase();
    if (upper.contains('INTERVAL=2') && upper.contains('WEEKLY')) {
      return ReminderRecurrence.biweekly;
    }
    if (upper.contains('INTERVAL=15') && upper.contains('DAILY')) {
      return ReminderRecurrence.biweekly;
    }
    if (upper.contains('BIWEEKLY') || upper.contains('QUINCENAL')) {
      return ReminderRecurrence.biweekly;
    }
    if (upper.contains('FREQ=DAILY') || upper.contains('DIARIO')) {
      return ReminderRecurrence.daily;
    }
    if (upper.contains('FREQ=WEEKLY') || upper.contains('SEMANAL')) {
      return ReminderRecurrence.weekly;
    }
    if (upper.contains('FREQ=MONTHLY') || upper.contains('MENSUAL')) {
      return ReminderRecurrence.monthly;
    }
    if (upper.contains('FREQ=YEARLY') || upper.contains('ANUAL')) {
      return ReminderRecurrence.yearly;
    }
    return ReminderRecurrence.none;
  }

  /// Calcula la fecha de la siguiente ocurrencia a partir de una fecha base
  DateTime calculateNextDueDate(DateTime baseDate) {
    switch (this) {
      case ReminderRecurrence.none:
        return baseDate;
      case ReminderRecurrence.daily:
        return baseDate.add(const Duration(days: 1));
      case ReminderRecurrence.weekly:
        return baseDate.add(const Duration(days: 7));
      case ReminderRecurrence.biweekly:
        return baseDate.add(const Duration(days: 14));
      case ReminderRecurrence.monthly:
        final nextMonth = baseDate.month == 12 ? 1 : baseDate.month + 1;
        final nextYear = baseDate.month == 12 ? baseDate.year + 1 : baseDate.year;
        final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final day = baseDate.day > lastDayOfNextMonth ? lastDayOfNextMonth : baseDate.day;
        return DateTime(nextYear, nextMonth, day, baseDate.hour, baseDate.minute);
      case ReminderRecurrence.yearly:
        return DateTime(baseDate.year + 1, baseDate.month, baseDate.day, baseDate.hour, baseDate.minute);
    }
  }
}

class ReminderModel {
  final String id;
  final String? userId;
  final String title;
  final String? notes;
  final ReminderPriority priority;
  final ReminderStatus status;
  final DateTime? dueAt;
  final String clientTimezone;
  final String? rrule;
  final String? parentId;
  final bool isNagging;
  final int nagIntervalMinutes;
  final DateTime? lastNotifiedAt;
  final List<String> tags;
  final DateTime? completedAt;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReminderModel({
    required this.id,
    this.userId,
    required this.title,
    this.notes,
    this.priority = ReminderPriority.p3Medium,
    this.status = ReminderStatus.pending,
    this.dueAt,
    this.clientTimezone = 'UTC',
    this.rrule,
    this.parentId,
    this.isNagging = false,
    this.nagIntervalMinutes = 10,
    this.lastNotifiedAt,
    List<String>? tags,
    this.completedAt,
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ReminderRecurrence get recurrence => ReminderRecurrence.fromRrule(rrule);
  bool get isRecurring => recurrence != ReminderRecurrence.none;

  bool get isCompleted => status == ReminderStatus.completed;
  bool get isSnoozed => status == ReminderStatus.snoozed;
  bool get isArchived => status == ReminderStatus.archived;

  bool get isOverdue {
    if (dueAt == null || isCompleted || isArchived) return false;
    return dueAt!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (dueAt == null || isCompleted || isArchived) return false;
    final now = DateTime.now();
    return dueAt!.year == now.year &&
        dueAt!.month == now.month &&
        dueAt!.day == now.day;
  }

  bool get isUpcoming {
    if (dueAt == null || isCompleted || isArchived) return false;
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return dueAt!.isAfter(todayEnd);
  }

  String get formattedDueTime {
    if (dueAt == null) return 'Sin fecha límite';
    final local = dueAt!.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = local.year == tomorrow.year && local.month == tomorrow.month && local.day == tomorrow.day;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    if (isToday) {
      return 'Hoy a las $timeStr';
    } else if (isTomorrow) {
      return 'Mañana a las $timeStr';
    } else {
      final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${days[local.weekday - 1]} ${local.day} ${months[local.month - 1]}, $timeStr';
    }
  }

  /// Texto legible de tiempo restante en días y horas
  String get timeRemainingFormatted {
    if (dueAt == null) return 'Sin fecha límite';
    final now = DateTime.now();
    final difference = dueAt!.difference(now);

    if (difference.isNegative) {
      final absDiff = difference.abs();
      final totalMinutes = (absDiff.inSeconds / 60).round();
      final days = totalMinutes ~/ (24 * 60);
      final hours = (totalMinutes % (24 * 60)) ~/ 60;
      final minutes = totalMinutes % 60;

      if (days > 0) {
        return 'Vencido hace ${days}d ${hours}h';
      } else if (hours > 0) {
        return 'Vencido hace ${hours}h ${minutes}m';
      } else {
        return 'Vencido hace ${minutes}m';
      }
    }

    final totalMinutes = (difference.inSeconds / 60).round();
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;

    if (days > 0) {
      if (hours > 0) {
        return 'Faltan $days días y $hours ${hours == 1 ? "hora" : "horas"}';
      } else {
        return 'Faltan $days ${days == 1 ? "día" : "días"}';
      }
    } else if (hours > 0) {
      if (minutes > 0) {
        return 'Faltan $hours ${hours == 1 ? "hora" : "horas"} y $minutes min';
      } else {
        return 'Faltan $hours ${hours == 1 ? "hora" : "horas"}';
      }
    } else if (minutes > 0) {
      return 'Faltan $minutes ${minutes == 1 ? "minuto" : "minutos"}';
    } else {
      return '¡Es ahora!';
    }
  }

  ReminderModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? notes,
    bool clearNotes = false,
    ReminderPriority? priority,
    ReminderStatus? status,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? clientTimezone,
    String? rrule,
    bool clearRrule = false,
    String? parentId,
    bool? isNagging,
    int? nagIntervalMinutes,
    DateTime? lastNotifiedAt,
    List<String>? tags,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      clientTimezone: clientTimezone ?? this.clientTimezone,
      rrule: clearRrule ? null : (rrule ?? this.rrule),
      parentId: parentId ?? this.parentId,
      isNagging: isNagging ?? this.isNagging,
      nagIntervalMinutes: nagIntervalMinutes ?? this.nagIntervalMinutes,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
      tags: tags ?? List.from(this.tags),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'notes': notes,
      'priority': priority.code,
      'status': status.code,
      'due_at': dueAt?.toUtc().toIso8601String(),
      'client_timezone': clientTimezone,
      'rrule': rrule,
      'parent_id': parentId,
      'is_nagging': isNagging,
      'nag_interval_minutes': nagIntervalMinutes,
      'last_notified_at': lastNotifiedAt?.toUtc().toIso8601String(),
      'tags': tags,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'is_pinned': isPinned,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    if (map['tags'] is List) {
      parsedTags = (map['tags'] as List).map((t) => t.toString()).toList();
    }

    return ReminderModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      title: map['title']?.toString() ?? '',
      notes: map['notes']?.toString(),
      priority: ReminderPriority.fromString(map['priority']?.toString()),
      status: ReminderStatus.fromString(map['status']?.toString()),
      dueAt: map['due_at'] != null ? DateTime.tryParse(map['due_at'].toString())?.toLocal() : null,
      clientTimezone: map['client_timezone']?.toString() ?? 'UTC',
      rrule: map['rrule']?.toString(),
      parentId: map['parent_id']?.toString(),
      isNagging: map['is_nagging'] == true,
      nagIntervalMinutes: map['nag_interval_minutes'] is int
          ? map['nag_interval_minutes']
          : int.tryParse(map['nag_interval_minutes']?.toString() ?? '10') ?? 10,
      lastNotifiedAt: map['last_notified_at'] != null
          ? DateTime.tryParse(map['last_notified_at'].toString())?.toLocal()
          : null,
      tags: parsedTags,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())?.toLocal()
          : null,
      isPinned: map['is_pinned'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
