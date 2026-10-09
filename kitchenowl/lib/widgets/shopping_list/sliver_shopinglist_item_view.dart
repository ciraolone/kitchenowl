/// Lista della spesa sotto il campo di ricerca: gli articoli in lista e sotto
/// gli articoli recenti. Nell'ordinamento per reparti gli articoli in lista li
/// mostra SliverShoppinglistCategories, che tiene anche lo stato dei
/// trascinamenti fra reparti; negli altri ordinamenti sono un'unica griglia.
/// Il trascinamento degli articoli (feature 004-riordino-trascinamento del
/// fork di Andrea) c'è solo se la pagina passa onArrange e onMoveToCategory, e
/// mai nell'ordinamento alfabetico.
library;

import 'package:flutter/material.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/widgets/home_page/sliver_category_item_grid_list.dart';
import 'package:kitchenowl/widgets/shopping_list/arrangeable_item.dart';
import 'package:kitchenowl/widgets/shopping_list/sliver_shoppinglist_categories.dart';

class SliverShopinglistItemView extends StatelessWidget {
  final ShoppingList? shoppingList;
  final List<Category> categories;
  final void Function()? onRefresh;
  final Nullable<void Function(ShoppinglistItem)>? onPressed;
  final Nullable<void Function(ShoppinglistItem)>? onLongPressed;
  final Nullable<void Function(ItemWithDescription)>? onRecentPressed;
  final Nullable<void Function(ItemWithDescription)>? onRecentLongPressed;
  final ShoppinglistSorting sorting;
  final bool isLoading;
  final List<ShoppinglistItem> selectedListItems;
  final ShoppingListStyle shoppingListStyle;

  /// Trascinamento (features/004): su un altro articolo e sulla riga di un
  /// reparto. Senza questi, o nell'ordinamento alfabetico, non si trascina.
  final void Function(ShoppinglistItem moved, ShoppinglistItem target)?
      onArrange;
  final void Function(ShoppinglistItem moved, Category? category)?
      onMoveToCategory;

  /// Trascinamento di un reparto su un altro (features/005).
  final void Function(Category moved, Category target)? onArrangeCategory;

  const SliverShopinglistItemView({
    super.key,
    this.shoppingList,
    required this.categories,
    this.onRefresh,
    this.onPressed,
    this.onLongPressed,
    this.onRecentPressed,
    this.onRecentLongPressed,
    required this.sorting,
    required this.isLoading,
    required this.selectedListItems,
    this.shoppingListStyle = const ShoppingListStyle(),
    this.onArrange,
    this.onMoveToCategory,
    this.onArrangeCategory,
  });

  bool get _isByCategory =>
      sorting == ShoppinglistSorting.category &&
      !(isLoading && (shoppingList?.items.isEmpty ?? false));

  bool _isSelected(ShoppinglistItem item) =>
      App.settings.shoppingListTapToRemove &&
          !App.settings.shoppingListListView ||
      !App.settings.shoppingListTapToRemove &&
          App.settings.shoppingListListView ^ !selectedListItems.contains(item);

  // Nella griglia unica non c'è nulla da chiudere durante il trascinamento
  ItemArrangement<ShoppinglistItem>? get _arrangement {
    final onArrange = this.onArrange;
    if (onArrange == null ||
        onMoveToCategory == null ||
        sorting == ShoppinglistSorting.alphabetical) {
      return null;
    }
    return ItemArrangement(
      onStart: (item) {},
      onEnd: () {},
      onDrop: onArrange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: [
      if (_isByCategory)
        SliverShoppinglistCategories(
          shoppingList: shoppingList,
          categories: categories,
          selected: _isSelected,
          isLoading: isLoading,
          onRefresh: onRefresh,
          onPressed: onPressed,
          onLongPressed: onLongPressed,
          shoppingListStyle: shoppingListStyle,
          onArrange: onArrange,
          onMoveToCategory: onMoveToCategory,
          onArrangeCategory: onArrangeCategory,
        ),
      if (!_isByCategory)
        SliverItemGridList<ShoppinglistItem>(
          items: shoppingList?.items ?? [],
          categories: categories,
          shoppingList: shoppingList,
          selected: _isSelected,
          isLoading: isLoading,
          onRefresh: onRefresh,
          onPressed: onPressed,
          onLongPressed: onLongPressed,
          shoppingListStyle: shoppingListStyle,
          arrangement: _arrangement,
        ),
      if (((shoppingList?.recentItems.isNotEmpty ?? false) &&
              (App.settings.recentItemsCount > 0)) ||
          isLoading)
        SliverCategoryItemGridList<ItemWithDescription>(
          name: '${AppLocalizations.of(context)!.itemsRecent}:',
          items: shoppingList?.recentItems
                  .take(App.settings.recentItemsCount)
                  .toList() ??
              [],
          onPressed: onRecentPressed,
          onLongPressed: onRecentLongPressed,
          categories: categories,
          shoppingList: shoppingList,
          onRefresh: onRefresh,
          isLoading: isLoading,
          shoppingListStyle: shoppingListStyle,
          splitByCategories:
              App.settings.recentItemsCategorize && _isByCategory,
        ),
    ]);
  }
}
