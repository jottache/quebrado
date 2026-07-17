import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/transaction_category.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../dialogs/add_category_dialog.dart';
import '../theme/colors.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Segmented tab filtered lists
    final incomeCategories = appState.getParentCategories(TransactionCategoryType.income)
      ..sort((a, b) => a.position.compareTo(b.position));

    final expenseCategories = appState.getParentCategories(TransactionCategoryType.expense)
      ..sort((a, b) => a.position.compareTo(b.position));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: EdgeInsets.only(right: 0),
          child: Image.asset(
            'assets/images/quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () {
              final initialType = _tabController.index == 0
                  ? TransactionCategoryType.income
                  : TransactionCategoryType.expense;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    AddCategoryBottomSheet(initialType: initialType),
              );
            },
          ),
        ],
      ),
      body: ClaymorphicBackground(
        child: Column(
          children: [
            // Segmented Tab Selector
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Container(
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: AppColors.mainTabTrackBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.mainTabActiveBg,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: AppColors.mainTabActiveText,
                  unselectedLabelColor: AppColors.mainTabInactiveText,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(text: "Ingresos"),
                    Tab(text: "Gastos"),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCategoryList(context, appState, incomeCategories),
                  _buildCategoryList(context, appState, expenseCategories),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    AppState appState,
    List<TransactionCategory> categories,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tag_rounded, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                "Sin categorías",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Crea una nueva categoría presionando el botón '+' en la esquina superior derecha.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: EdgeInsets.all(16.0),
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final list = List<TransactionCategory>.from(categories);
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        appState.reorderCategories(list);
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        final subcategories = appState.getSubcategories(category.id)
          ..sort((a, b) => a.position.compareTo(b.position));

        return Padding(
          key: Key(category.id),
          padding: EdgeInsets.only(bottom: 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCategoryItem(context, appState, category, index, isSubcategory: false),
              if (subcategories.isNotEmpty) SizedBox(height: 4),
              ...subcategories.map((sub) => _buildCategoryItem(context, appState, sub, index, isSubcategory: true)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    AppState appState,
    TransactionCategory category,
    int index, {
    bool isSubcategory = false,
  }) {
    final color = parseHexColor(category.colorHex);

    return Padding(
      padding: EdgeInsets.only(
        bottom: isSubcategory ? 8.0 : 12.0,
        left: isSubcategory ? 32.0 : 0.0,
      ),
      child: Dismissible(
        key: Key('dismiss_${category.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.0),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.delete_forever_rounded,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Text(
                    "Confirmar Eliminación",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    "¿Estás seguro de que deseas eliminar la categoría '${category.name}'?",
                    style: TextStyle(fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "Cancelar",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        "Eliminar",
                        style: TextStyle(
                          color: AppColors.expense,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        onDismissed: (_) {
          appState.deleteCategory(category.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Categoría '${category.name}' eliminada"),
            ),
          );
        },
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddCategoryBottomSheet(
                initialType: category.type,
                editingCategory: category,
              ),
            );
          },
          child: ClaymorphicCard(
            cornerRadius: 18,
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            backgroundColor: isSubcategory ? AppColors.cardBackground : AppColors.getAlternateCardColor(index),
            child: Row(
              children: [
                if (isSubcategory)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.subdirectory_arrow_right_rounded, color: AppColors.cardSubtitleText, size: 16),
                  ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    getIconData(category.icon),
                    color: color,
                    size: 18,
                  ),
                ),
                SizedBox(width: 14),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardText,
                  ),
                ),
                Spacer(),
                if (!isSubcategory)
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: AppColors.cardSubtitleText.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
