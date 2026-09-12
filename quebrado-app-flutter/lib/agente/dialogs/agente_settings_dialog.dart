import 'package:flutter/material.dart';
import '../services/gemini_config.dart';
import '../theme/agente_colors.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AgenteColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: AgenteColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajustes del Agente IA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Configuración de Gemini API y Modelo',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Gemini API Key Input
              const Text(
                'GEMINI API KEY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AgenteColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AgenteColors.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Obtén tu API key gratuita en aistudio.google.com',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),

              // Model Selection
              const Text(
                'MODELO DE LENGUAJE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildModelOption(
                      title: 'Gemini 1.5 Flash',
                      subtitle: 'Ultra rápido (<1s) & Ligero',
                      value: 'gemini-1.5-flash',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModelOption(
                      title: 'Gemini 1.5 Pro',
                      subtitle: 'Mayor razonamiento',
                      value: 'gemini-1.5-pro',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: () {
                  GeminiConfig.setApiKey(_apiKeyController.text);
                  GeminiConfig.setModel(_selectedModel);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ajustes del Agente guardados correctamente.'),
                      backgroundColor: AgenteColors.primaryDark,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgenteColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Guardar Configuración',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AgenteColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AgenteColors.primary : AgenteColors.cardBorder,
            width: isSelected ? 2 : 1,
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AgenteColors.primaryDark : Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 16, color: AgenteColors.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
