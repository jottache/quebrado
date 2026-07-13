import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exchange_rate_record.dart';

class RateServiceException implements Exception {
  final String message;
  RateServiceException(this.message);

  @override
  String toString() => message;
}

class RateService {
  static final String _officialUSDUrl = "https://ve.dolarapi.com/v1/dolares/oficial";
  static final String _parallelUSDUrl = "https://ve.dolarapi.com/v1/dolares/paralelo";
  static final String _officialEURUrl = "https://ve.dolarapi.com/v1/euros/oficial";
  static final String _bcvHistoricUrl = "https://ve.dolarapi.com/v1/historicos/dolares/oficial";
  static final String _euroHistoricUrl = "https://ve.dolarapi.com/v1/historicos/euros/oficial";

  /// Fetches latest official USD exchange rate (BCV)
  Future<double> fetchOfficialRate() async {
    return await _fetchSingleRate(_officialUSDUrl);
  }

  /// Fetches latest parallel USD exchange rate
  Future<double> fetchParallelRate() async {
    return await _fetchSingleRate(_parallelUSDUrl);
  }

  /// Fetches latest official EUR exchange rate
  Future<double> fetchEuroRate() async {
    return await _fetchSingleRate(_officialEURUrl);
  }

  /// Fetches entire historical timeline for BCV, filtering out weekends
  Future<List<ExchangeRateRecord>> fetchHistoricRates() async {
    return await _fetchHistoricData(_bcvHistoricUrl, 'bcv');
  }

  /// Fetches entire historical timeline for Euro, filtering out weekends
  Future<List<ExchangeRateRecord>> fetchEuroHistoricRates() async {
    return await _fetchHistoricData(_euroHistoricUrl, 'euro');
  }

  // MARK: - Private Helpers

  Future<double> _fetchSingleRate(String urlString) async {
    try {
      final response = await http.get(
        Uri.parse(urlString),
        headers: {'Cache-Control': 'no-cache'},
      );

      if (response.statusCode != 200) {
        throw RateServiceException("El servidor devolvió una respuesta incorrecta: ${response.statusCode}");
      }

      final data = json.decode(response.body);
      return (data['promedio'] as num).toDouble();
    } catch (e) {
      if (e is RateServiceException) rethrow;
      throw RateServiceException("Error de conexión al obtener la tasa: ${e.toString()}");
    }
  }

  Future<List<ExchangeRateRecord>> _fetchHistoricData(String urlString, String prefix) async {
    try {
      final response = await http.get(
        Uri.parse(urlString),
        headers: {'Cache-Control': 'no-cache'},
      );

      if (response.statusCode != 200) {
        throw RateServiceException("El servidor devolvió una respuesta incorrecta: ${response.statusCode}");
      }

      final List decoded = json.decode(response.body);
      final List<ExchangeRateRecord> records = [];

      for (var entry in decoded) {
        final double promedio = (entry['promedio'] as num).toDouble();
        final String fechaStr = entry['fecha']; // e.g., "2026-06-16"

        try {
          final date = DateTime.parse(fechaStr);
          
          // Skip weekend rate records (weekday: 6 = Saturday, 7 = Sunday in Dart DateTime)
          // Dart DateTime.weekday starts from 1 (Monday) to 7 (Sunday)
          if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
            continue;
          }

          records.add(ExchangeRateRecord(
            id: entry['id'] ?? "${prefix}_${date.millisecondsSinceEpoch}",
            date: date,
            rate: promedio,
          ));
        } catch (_) {
          // Skip invalid entries
        }
      }

      // Sort by date descending (latest first)
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (e) {
      if (e is RateServiceException) rethrow;
      throw RateServiceException("Error al procesar el historial de tasas: ${e.toString()}");
    }
  }
}
