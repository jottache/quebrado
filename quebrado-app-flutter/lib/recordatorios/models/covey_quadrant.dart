import 'package:flutter/material.dart';

/// Cuadrantes de Covey (Hábito 3: "Primero lo Primero").
enum CoveyQuadrant {
  q1UrgentImportant,      // Cuadrante I: Crisis, problemas apremiantes, fechas límite
  q2ImportantNotUrgent,   // Cuadrante II: Preparación, prevención, salud, relaciones (NÚCLEO)
  q3UrgentNotImportant,   // Cuadrante III: Interrupciones, presiones ajenas, urgencias menores
  q4NotUrgentNotImportant;// Cuadrante IV: Desperdicio, escape excesivo, trivialidades

  String get code {
    switch (this) {
      case CoveyQuadrant.q1UrgentImportant:
        return 'q1_urgent_important';
      case CoveyQuadrant.q2ImportantNotUrgent:
        return 'q2_important_not_urgent';
      case CoveyQuadrant.q3UrgentNotImportant:
        return 'q3_urgent_not_important';
      case CoveyQuadrant.q4NotUrgentNotImportant:
        return 'q4_not_urgent_not_important';
    }
  }

  String get shortLabel {
    switch (this) {
      case CoveyQuadrant.q1UrgentImportant:
        return 'C1';
      case CoveyQuadrant.q2ImportantNotUrgent:
        return 'C2';
      case CoveyQuadrant.q3UrgentNotImportant:
        return 'C3';
      case CoveyQuadrant.q4NotUrgentNotImportant:
        return 'C4';
    }
  }

  String get title {
    switch (this) {
      case CoveyQuadrant.q1UrgentImportant:
        return 'Urgente e Importante';
      case CoveyQuadrant.q2ImportantNotUrgent:
        return 'Importante, No Urgente';
      case CoveyQuadrant.q3UrgentNotImportant:
        return 'Urgente, No Importante';
      case CoveyQuadrant.q4NotUrgentNotImportant:
        return 'No Urgente, Ni Importante';
    }
  }

  String get subtitle {
    switch (this) {
      case CoveyQuadrant.q1UrgentImportant:
        return 'Crisis y Fechas Límite';
      case CoveyQuadrant.q2ImportantNotUrgent:
        return 'Liderazgo, Salud y Efectividad';
      case CoveyQuadrant.q3UrgentNotImportant:
        return 'Interrupciones y Urgencias Ajenas';
      case CoveyQuadrant.q4NotUrgentNotImportant:
        return 'Escape y Pérdida de Tiempo';
    }
  }

  Color get color {
    switch (this) {
      case CoveyQuadrant.q1UrgentImportant:
        return const Color(0xFFDC2626); // Carmesí / Rojo
      case CoveyQuadrant.q2ImportantNotUrgent:
        return const Color(0xFF059669); // Esmeralda / Verde (Foco primordial)
      case CoveyQuadrant.q3UrgentNotImportant:
        return const Color(0xFFD97706); // Ámbar / Naranja
      case CoveyQuadrant.q4NotUrgentNotImportant:
        return const Color(0xFF64748B); // Pizarra / Gris
    }
  }

  Color get lightBackgroundColor {
    switch (this) {
      case CoveyQuadrant.q1UrgentImportant:
        return const Color(0xFFFEF2F2);
      case CoveyQuadrant.q2ImportantNotUrgent:
        return const Color(0xFFECFDF5);
      case CoveyQuadrant.q3UrgentNotImportant:
        return const Color(0xFFFFFBEB);
      case CoveyQuadrant.q4NotUrgentNotImportant:
        return const Color(0xFFF8FAFC);
    }
  }

  Color get borderColor {
    switch (this) {
      case CoveyQuadrant.q1UrgentImportant:
        return const Color(0xFFFCA5A5);
      case CoveyQuadrant.q2ImportantNotUrgent:
        return const Color(0xFF6EE7B7);
      case CoveyQuadrant.q3UrgentNotImportant:
        return const Color(0xFFFCD34D);
      case CoveyQuadrant.q4NotUrgentNotImportant:
        return const Color(0xFFCBD5E1);
    }
  }

  String get label => '$shortLabel $title';
  String get description => subtitle;
  bool get isQuadrant2 => this == CoveyQuadrant.q2ImportantNotUrgent;

  static CoveyQuadrant fromCode(String? value) => fromString(value);

  static CoveyQuadrant fromString(String? value) {
    if (value == null) return CoveyQuadrant.q2ImportantNotUrgent;
    final lower = value.toLowerCase().trim();
    if (lower.contains('q1') || lower.contains('c1') || lower.contains('crisis')) {
      return CoveyQuadrant.q1UrgentImportant;
    }
    if (lower.contains('q2') || lower.contains('c2') || lower.contains('efectividad') || lower.contains('importante')) {
      return CoveyQuadrant.q2ImportantNotUrgent;
    }
    if (lower.contains('q3') || lower.contains('c3') || lower.contains('interrupcion')) {
      return CoveyQuadrant.q3UrgentNotImportant;
    }
    if (lower.contains('q4') || lower.contains('c4') || lower.contains('desperdicio') || lower.contains('escape')) {
      return CoveyQuadrant.q4NotUrgentNotImportant;
    }
    return CoveyQuadrant.q2ImportantNotUrgent;
  }
}
