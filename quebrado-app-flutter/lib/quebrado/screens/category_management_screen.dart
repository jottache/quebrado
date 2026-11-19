import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/transaction_category.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/helpers.dart';
import '../dialogs/add_category_dialog.dart';
import '../theme/colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

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
        title: Image.asset(
          'assets/images/quebrado/logo_quebrado.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: "Nueva categoría",
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppColors.primary,
              size: OrtizIconSize.lg,
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
              padding: const EdgeInsets.symmetric(
                horizontal: OrtizSpace.lg,
                vertical: OrtizSpace.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(OrtizSpace.xs),
                decoration: BoxDecoration(
                  color: AppColors.mainTabTrackBg,
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.mainTabActiveBg,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                  labelColor: AppColors.mainTabActiveText,
                  unselectedLabelColor: AppColors.mainTabInactiveText,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: OrtizFontSize.bodySm,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: OrtizFontSize.bodySm,
                  ),
                  tabs: const [
                    Tab(text: "Ingresos"),
                    Tab(text: "Gastos"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: OrtizSpace.sm),

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
      return const OrtizEmptyState(
        icon: Icons.tag_rounded,
        title: "Sin categorías",
        message: "Crea una nueva categoría presionando el botón '+' en la esquina superior derecha.",
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(OrtizSpace.lg),
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

        // Grupo sin tarjeta: la categoría y sus subcategorías, y una línea
        // hasta la siguiente.
        return Column(
          key: Key(category.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCategoryItem(context, appState, category, index, isSubcategory: false),
            ...subcategories.map((sub) => _buildCategoryItem(context, appState, sub, index, isSubcategory: true)),
            const Divider(height: OrtizSpace.md),
          ],
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
      padding: EdgeInsets.only(left: isSubcategory ? OrtizSpace.xxl : 0),
      child: Dismissible(
        key: Key('dismiss_${category.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: OrtizSpace.xl),
          decoration: BoxDecoration(
            color: OrtizPalette.bad,
            borderRadius: BorderRadius.circular(OrtizRadius.field),
          ),
          child: const Icon(
            Icons.delete_forever_rounded,
            color: OrtizPalette.onAccent,
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                  ),
                  title: const Text(
                    "Confirmar Eliminación",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    "¿Estás seguro de que deseas eliminar la categoría '${category.name}'?",
                    style: const TextStyle(fontSize: OrtizFontSize.bodySm),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        "Cancelar",
                        style: TextStyle(
                          color: OrtizPalette.muted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
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
        child: OrtizListRow(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSubcategory) ...[
                const Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  color: AppColors.cardSubtitleText,
                  size: OrtizIconSize.sm,
                ),
                const SizedBox(width: OrtizSpace.xs),
              ],
              Icon(getIconData(category.icon), color: color),
            ],
          ),
          title: category.name,
          trailing: isSubcategory
              ? null
              : ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    color: AppColors.cardSubtitleText,
                  ),
                ),
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
        ),
      ),
    );
  }
}
