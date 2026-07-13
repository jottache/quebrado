import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_store.dart';

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
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottomInset > 0 ? bottomInset + 16 : 32,
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
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Añadir Establecimiento",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Text(
                "Nombre del establecimiento",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: 4),
              TextField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  hintText: "Ej. Frutería Los Hermanos",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  contentPadding: EdgeInsets.all(12),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: 13, color: AppColors.cardText),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Guardar Establecimiento",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
