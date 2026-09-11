import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit_model.dart';
import '../models/habit_log_model.dart';
import '../models/habit_stack_model.dart';
import '../../services/supabase_config.dart';

class HabitosBootstrapData {
  final List<HabitModel> habits;
  final List<HabitStackModel> stacks;
  final List<HabitLogModel> logs;

  HabitosBootstrapData({
    required this.habits,
    required this.stacks,
    required this.logs,
  });
}

class HabitosSupabaseService {
  final SupabaseClient? _client;

  HabitosSupabaseService({SupabaseClient? client})
      : _client = client ?? (SupabaseConfig.isConfigured ? Supabase.instance.client : null);

  bool get isRemoteAvailable => _client != null && SupabaseConfig.isConfigured;

  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Carga inicial en paralelo de hábitos, rutinas y registros de los últimos 365 días
  Future<HabitosBootstrapData> bootstrapData() async {
    if (!isRemoteAvailable) {
      debugPrint('[Habitos] Supabase no configurado, utilizando semillas CLI en memoria');
      return _generateDefaultSeedData();
    }

    try {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final oneYearAgoIso = "${oneYearAgo.year.toString().padLeft(4, '0')}-${oneYearAgo.month.toString().padLeft(2, '0')}-${oneYearAgo.day.toString().padLeft(2, '0')}";

      final results = await Future.wait([
        _client!
            .from('habits')
            .select()
            .eq('archived', false)
            .order('position', ascending: true),
        _client!
            .from('habit_stacks')
            .select()
            .order('position', ascending: true),
        _client!
            .from('habit_logs')
            .select()
            .gte('log_date', oneYearAgoIso),
      ]);

      final habitsRaw = results[0] as List<dynamic>;
      final stacksRaw = results[1] as List<dynamic>;
      final logsRaw = results[2] as List<dynamic>;

      if (habitsRaw.isEmpty) {
        debugPrint('[Habitos] Base de datos vacía, inicializando semillas de bienvenida');
        final seedData = _generateDefaultSeedData();
        for (final s in seedData.stacks) {
          await saveHabitStack(s);
        }
        for (final h in seedData.habits) {
          await saveHabit(h);
        }
        for (final l in seedData.logs) {
          await saveHabitLog(l);
        }
        return seedData;
      }

      final habits = habitsRaw.map((m) => HabitModel.fromMap(m as Map<String, dynamic>)).toList();
      final stacks = stacksRaw.map((m) => HabitStackModel.fromMap(m as Map<String, dynamic>)).toList();
      final logs = logsRaw.map((m) => HabitLogModel.fromMap(m as Map<String, dynamic>)).toList();

      return HabitosBootstrapData(habits: habits, stacks: stacks, logs: logs);
    } catch (e) {
      debugPrint('[Habitos] Error cargando desde Supabase: $e. Usando datos locales.');
      return _generateDefaultSeedData();
    }
  }

  Future<void> saveHabit(HabitModel habit) async {
    if (!isRemoteAvailable) return;
    try {
      final map = habit.toMap();
      if (currentUserId != null) map['user_id'] = currentUserId;
      await _client!.from('habits').upsert(map);
    } catch (e) {
      debugPrint('[Habitos] Error guardando habit: $e');
    }
  }

  Future<void> deleteHabit(String habitId) async {
    if (!isRemoteAvailable) return;
    try {
      await _client!.from('habits').delete().eq('id', habitId);
    } catch (e) {
      debugPrint('[Habitos] Error eliminando habit: $e');
    }
  }

  Future<void> saveHabitLog(HabitLogModel log) async {
    if (!isRemoteAvailable) return;
    try {
      final map = log.toMap();
      if (currentUserId != null) map['user_id'] = currentUserId;
      await _client!.from('habit_logs').upsert(map, onConflict: 'habit_id,log_date');
    } catch (e) {
      debugPrint('[Habitos] Error guardando habit_log: $e');
    }
  }

  Future<void> saveHabitStack(HabitStackModel stack) async {
    if (!isRemoteAvailable) return;
    try {
      final map = stack.toMap();
      if (currentUserId != null) map['user_id'] = currentUserId;
      await _client!.from('habit_stacks').upsert(map);
    } catch (e) {
      debugPrint('[Habitos] Error guardando habit_stack: $e');
    }
  }

  Future<void> deleteHabitStack(String stackId) async {
    if (!isRemoteAvailable) return;
    try {
      await _client!.from('habit_stacks').delete().eq('id', stackId);
    } catch (e) {
      debugPrint('[Habitos] Error eliminando habit_stack: $e');
    }
  }

  // ===========================================================================
  // SEMILLAS DE BIENVENIDA CON HISTORIAL PARA HEATMAP CLI
  // ===========================================================================
  HabitosBootstrapData _generateDefaultSeedData() {
    final now = DateTime.now();

    final stacks = [
      HabitStackModel(
        id: 'stack_morning',
        name: 'RUTINA_MANANA',
        timeOfDay: 'morning',
        icon: 'terminal',
        position: 1,
      ),
      HabitStackModel(
        id: 'stack_evening',
        name: 'RUTINA_NOCHE',
        timeOfDay: 'evening',
        icon: 'terminal',
        position: 2,
      ),
    ];

    final habits = [
      // 1. Cuantitativo: Agua
      HabitModel(
        id: 'habit_water',
        title: 'Hidratacion [2500 ml]',
        description: 'Ingerir agua a lo largo del día para rendimiento cognitivo.',
        icon: 'water_drop',
        colorHex: '#00FF66',
        type: HabitType.quantitative,
        targetValue: 2500,
        unit: 'ml',
        stackGroupId: 'stack_morning',
        position: 1,
      ),
      // 2. Temporizador: Meditación
      HabitModel(
        id: 'habit_meditation',
        title: 'Meditacion Zen [10 min]',
        description: 'Pausa de mindfulness para reducción de cortisol.',
        icon: 'timer',
        colorHex: '#00FF66',
        type: HabitType.timer,
        targetValue: 600, // 10 min en segundos
        unit: 'min',
        stackGroupId: 'stack_morning',
        position: 2,
      ),
      // 3. Cuantitativo: Lectura
      HabitModel(
        id: 'habit_reading',
        title: 'Lectura Tecnica [15 pag]',
        description: 'Lectura de libros o articulos de arquitectura y programacion.',
        icon: 'book',
        colorHex: '#00FF66',
        type: HabitType.quantitative,
        targetValue: 15,
        unit: 'pag',
        position: 3,
      ),
      // 4. Mal Hábito (Negativo): Cero Azúcar
      HabitModel(
        id: 'habit_no_sugar',
        title: 'Cero Azucar Refinada',
        description: 'Evitar gaseosas, golosinas y postres procesados.',
        icon: 'code_off',
        colorHex: '#FFB000',
        type: HabitType.negative,
        isNegative: true,
        targetValue: 1,
        position: 4,
      ),
      // 5. Mal Hábito (Negativo): Cero Tabaco / Fumar
      HabitModel(
        id: 'habit_no_smoke',
        title: 'Sin Tabaco / Fumar',
        description: 'Mantener pulmones limpios y salud cardiovascular.',
        icon: 'smoke_free',
        colorHex: '#FF3B30',
        type: HabitType.negative,
        isNegative: true,
        targetValue: 1,
        position: 5,
      ),
      // 6. Binario: Dormir temprano
      HabitModel(
        id: 'habit_sleep',
        title: 'Dormir antes de 23:30',
        description: 'Higiene del sueño para recuperación física y mental.',
        icon: 'bed',
        colorHex: '#00FF66',
        type: HabitType.binary,
        stackGroupId: 'stack_evening',
        position: 6,
      ),
    ];

    // Generar historial de los últimos 45 días para poblar el Heatmap CLI y las rachas
    final List<HabitLogModel> logs = [];

    for (int i = 0; i <= 45; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      // Simular cumplimiento alto (80% consistencia)
      final daySeed = (date.day * 7 + date.month * 31) % 10;

      // Agua
      final waterDone = daySeed > 2;
      logs.add(HabitLogModel(
        id: 'log_water_$dateStr',
        habitId: 'habit_water',
        logDate: dateStr,
        value: waterDone ? 2500 : 1500,
        completed: waterDone,
      ));

      // Meditación
      final medDone = daySeed > 3;
      logs.add(HabitLogModel(
        id: 'log_med_$dateStr',
        habitId: 'habit_meditation',
        logDate: dateStr,
        value: medDone ? 600 : 0,
        completed: medDone,
      ));

      // Lectura
      final readDone = daySeed > 1;
      logs.add(HabitLogModel(
        id: 'log_read_$dateStr',
        habitId: 'habit_reading',
        logDate: dateStr,
        value: readDone ? 15 : 8,
        completed: readDone,
      ));

      // Cero Azúcar (Mal hábito cumplido si NO recayó)
      final noSugarSuccess = daySeed != 5; // Solo recayó cuando seed == 5
      logs.add(HabitLogModel(
        id: 'log_sugar_$dateStr',
        habitId: 'habit_no_sugar',
        logDate: dateStr,
        value: noSugarSuccess ? 1 : 0,
        completed: noSugarSuccess,
      ));

      // Sin Fumar (Invicto total)
      logs.add(HabitLogModel(
        id: 'log_smoke_$dateStr',
        habitId: 'habit_no_smoke',
        logDate: dateStr,
        value: 1,
        completed: true,
      ));

      // Dormir
      final sleepDone = daySeed > 3;
      logs.add(HabitLogModel(
        id: 'log_sleep_$dateStr',
        habitId: 'habit_sleep',
        logDate: dateStr,
        value: sleepDone ? 1 : 0,
        completed: sleepDone,
      ));
    }

    return HabitosBootstrapData(habits: habits, stacks: stacks, logs: logs);
  }
}
