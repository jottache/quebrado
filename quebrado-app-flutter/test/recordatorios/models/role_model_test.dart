import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/recordatorios/models/role_model.dart';
import 'package:quebrado_app_flutter/recordatorios/theme/reminders_colors.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  group('RoleModel.parseColorHex', () {
    test('lee el color elegido por la persona con o sin #', () {
      expect(RoleModel.parseColorHex('#10B981').toARGB32(), 0xFF10B981);
      expect(RoleModel.parseColorHex('F43F5E').toARGB32(), 0xFFF43F5E);
    });

    test('cae al color de rol por defecto de RemindersColors si el hex no vale',
        () {
      expect(RoleModel.parseColorHex('no-es-un-color'),
          RemindersColors.roleDefault);
    });

    test('el color de respaldo coincide con el colorHex por defecto del modelo',
        () {
      final rol = RoleModel(id: 'r1', name: 'Rol');
      expect(rol.color, RemindersColors.roleDefault);
    });

    test('el color de respaldo sirve de indicador sobre el fondo (≥ 3:1)', () {
      expect(_contraste(RemindersColors.roleDefault, OrtizPalette.bg),
          greaterThanOrEqualTo(3.0));
    });
  });

  group('RoleModel.fromMap/toMap', () {
    test('ida y vuelta conserva color, icono y posición', () {
      final rol = RoleModel.fromMap({
        'id': 'role_familia',
        'name': 'Familia',
        'color_hex': '#F43F5E',
        'icon': 'family',
        'position': 2,
        'archived': false,
        'created_at': '2026-09-28T12:00:00Z',
        'updated_at': '2026-09-28T12:00:00Z',
      });
      final map = rol.toMap();
      expect(map['color_hex'], '#F43F5E');
      expect(map['icon'], 'family');
      expect(map['position'], 2);
      expect(rol.iconData, Icons.family_restroom_rounded);
    });

    test('sin color_hex usa el azul por defecto', () {
      final rol = RoleModel.fromMap({'id': 'x', 'name': 'X'});
      expect(rol.colorHex, '#3B82F6');
    });
  });
}
