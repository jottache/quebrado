import 'package:flutter/material.dart';
import '../services/gemini_config.dart';
import '../theme/agente_colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class AgenteSettingsDialog extends StatefulWidget {
  const AgenteSettingsDialog({super.key});

  @override
  State<AgenteSettingsDialog> createState() => _AgenteSettingsDialogState();
}

class _AgenteSettingsDialogState extends State<AgenteSettingsDialog> {
  late TextEditingController _apiKeyController;
  late String _selectedModel;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: GeminiConfig.apiKey);
    _selectedModel = GeminiConfig.selectedModel;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.sheet)),
      backgroundColor: AgenteColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(OrtizSpace.sm),
                    decoration: BoxDecoration(
                      color: AgenteColors.primaryLight,
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: AgenteColors.primary,
                      size: OrtizIconSize.lg,
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajustes de Ortiz',
                          style: TextStyle(
                            fontSize: OrtizFontSize.title,
                            fontWeight: FontWeight.w900,
                            color: OrtizPalette.fg,
                          ),
                        ),
                        Text(
                          'Configuración de Gemini API y Modelo',
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, color: OrtizPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded, size: OrtizIconSize.md),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: OrtizSpace.xl),

              // Gemini API Key Input
              const Text(
                'GEMINI API KEY',
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: OrtizPalette.muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: OrtizSpace.sm),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  filled: true,
                  fillColor: AgenteColors.background,
                  prefixIcon: const Icon(Icons.vpn_key_outlined, size: OrtizIconSize.md),
                  suffixIcon: IconButton(
                    tooltip: _obscureKey ? 'Mostrar clave' : 'Ocultar clave',
                    icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility,
                      size: OrtizIconSize.md,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    borderSide: const BorderSide(color: AgenteColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                    borderSide: const BorderSide(color: AgenteColors.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: OrtizSpace.xs),
              const Text(
                'Obtén tu API key gratuita en aistudio.google.com',
                style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
              ),

              const SizedBox(height: OrtizSpace.xl),

              // Model Selection
              const Text(
                'MODELO DE LENGUAJE',
                style: TextStyle(
                  fontSize: OrtizFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: OrtizPalette.muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: OrtizSpace.sm),
              if (_selectedModel != 'gemini-1.5-flash' && _selectedModel != 'gemini-1.5-pro') ...[
                _buildModelOption(
                  title: 'Modelo Activo: $_selectedModel',
                  subtitle: 'Configurado en .env',
                  value: _selectedModel,
                ),
                const SizedBox(height: OrtizSpace.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: _buildModelOption(
                      title: 'Gemini 1.5 Flash',
                      subtitle: 'Ultra rápido & Ligero',
                      value: 'gemini-1.5-flash',
                    ),
                  ),
                  const SizedBox(width: OrtizSpace.sm),
                  Expanded(
                    child: _buildModelOption(
                      title: 'Gemini 1.5 Pro',
                      subtitle: 'Mayor razonamiento',
                      value: 'gemini-1.5-pro',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: OrtizSpace.xxl),

              // Save Button
              ElevatedButton(
                onPressed: () {
                  GeminiConfig.setApiKey(_apiKeyController.text);
                  GeminiConfig.setModel(_selectedModel);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ajustes de Ortiz guardados.'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgenteColors.primary,
                  foregroundColor: OrtizPalette.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Guardar Configuración',
                  style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelOption({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _selectedModel == value;

    return InkWell(
      onTap: () => setState(() => _selectedModel = value),
      borderRadius: BorderRadius.circular(OrtizRadius.field),
      child: Container(
        padding: const EdgeInsets.all(OrtizSpace.md),
        decoration: BoxDecoration(
          color: isSelected ? AgenteColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(OrtizRadius.field),
          border: Border.all(
            color: isSelected ? AgenteColors.primary : AgenteColors.cardBorder,
            width: isSelected ? OrtizStroke.focus : OrtizStroke.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AgenteColors.primaryDark : OrtizPalette.fg,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: OrtizIconSize.sm, color: AgenteColors.primary),
              ],
            ),
            const SizedBox(height: OrtizSpace.xs),
            Text(
              subtitle,
              style: const TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
