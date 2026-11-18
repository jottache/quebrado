import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_store.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class AddMarketStoreBottomSheet extends StatefulWidget {
  final Function(String) onStoreAdded;

  const AddMarketStoreBottomSheet({Key? key, required this.onStoreAdded}) : super(key: key);

  @override
  _AddMarketStoreBottomSheetState createState() => _AddMarketStoreBottomSheetState();
}

class _AddMarketStoreBottomSheetState extends State<AddMarketStoreBottomSheet> {
  final _storeNameController = TextEditingController();

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  void _saveStore() {
    if (_storeNameController.text.trim().isNotEmpty) {
      final newStore = MarketStore(
        id: Uuid().v4(),
        name: _storeNameController.text.trim(),
      );
      Provider.of<AppState>(context, listen: false).addMarketStore(newStore);
      Navigator.pop(context);
      widget.onStoreAdded(newStore.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: OrtizPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
        ),
        padding: EdgeInsets.only(
          left: OrtizSpace.lg,
          right: OrtizSpace.lg,
          top: OrtizSpace.lg,
          bottom: bottomInset > 0 ? bottomInset + OrtizSpace.lg : OrtizSpace.xxxl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OrtizPalette.faint,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.lg),
              Text(
                "Añadir Establecimiento",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: OrtizSpace.xxl),
              Text(
                "Nombre del establecimiento",
                style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: OrtizSpace.xs),
              TextField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  hintText: "Ej. Frutería Los Hermanos",
                  hintStyle: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                  contentPadding: EdgeInsets.all(OrtizSpace.md),
                  filled: true,
                  fillColor: OrtizPalette.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText),
              ),
              SizedBox(height: OrtizSpace.xxl),
              ElevatedButton(
                onPressed: _saveStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                  ),
                ),
                child: Text(
                  "Guardar Establecimiento",
                  style: TextStyle(
                    fontSize: OrtizFontSize.titleSm,
                    fontWeight: FontWeight.bold,
                    color: OrtizPalette.onAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
