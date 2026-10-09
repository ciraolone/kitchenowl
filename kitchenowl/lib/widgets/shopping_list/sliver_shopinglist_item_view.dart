import 'package:flutter/material.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/widgets/home_page/sliver_category_item_grid_list.dart';
import 'package:kitchenowl/widgets/shopping_list/arrangeable_item.dart';
import 'package:kitchenowl/widgets/shopping_list/sliver_category_drop_header.dart';

class SliverShopinglistItemView extends StatefulWidget {
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
  });

  @override
  State<SliverShopinglistItemView> createState() =>
      _SliverShopinglistItemViewState();
}

class _SliverShopinglistItemViewState extends State<SliverShopinglistItemView> {
  /// Articolo che si sta trascinando: nell'ordinamento per reparti, finché
  /// c'è, gli altri reparti si riducono a una riga su cui lasciarlo.
  ShoppinglistItem? _arrangingItem;

  bool get _isByCategory =>
      widget.sorting == ShoppinglistSorting.category &&
      !(widget.isLoading && (widget.shoppingList?.items.isEmpty ?? false));

  bool _isSelected(ShoppinglistItem item) =>
      App.settings.shoppingListTapToRemove &&
          !App.settings.shoppingListListView ||
      !App.settings.shoppingListTapToRemove &&
          App.settings.shoppingListListView ^
              !widget.selectedListItems.contains(item);

  ItemArrangement<ShoppinglistItem>? get _arrangement {
    final onArrange = widget.onArrange;
    if (onArrange == null ||
        widget.onMoveToCategory == null ||
        widget.sorting == ShoppinglistSorting.alphabetical) {
      return null;
    }
    return ItemArrangement(
      onStart: (item) => setState(() => _arrangingItem = item),
      onEnd: () {
        if (mounted) setState(() => _arrangingItem = null);
      },
      onDrop: onArrange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: [
      if (_isByCategory) ..._buildCategories(context),
      if (!_isByCategory)
        SliverItemGridList<ShoppinglistItem>(
          items: widget.shoppingList?.items ?? [],
          categories: widget.categories,
          shoppingList: widget.shoppingList,
          selected: _isSelected,
          isLoading: widget.isLoading,
          onRefresh: widget.onRefresh,
          onPressed: widget.onPressed,
          onLongPressed: widget.onLongPressed,
          shoppingListStyle: widget.shoppingListStyle,
          arrangement: _arrangement,
        ),
      if (((widget.shoppingList?.recentItems.isNotEmpty ?? false) &&
              (App.settings.recentItemsCount > 0)) ||
          widget.isLoading)
        SliverCategoryItemGridList<ItemWithDescription>(
          name: '${AppLocalizations.of(context)!.itemsRecent}:',
          items: widget.shoppingList?.recentItems
                  .take(App.settings.recentItemsCount)
                  .toList() ??
              [],
          onPressed: widget.onRecentPressed,
          onLongPressed: widget.onRecentLongPressed,
          categories: widget.categories,
          shoppingList: widget.shoppingList,
          onRefresh: widget.onRefresh,
          isLoading: widget.isLoading,
          shoppingListStyle: widget.shoppingListStyle,
          splitByCategories:
              App.settings.recentItemsCategorize && _isByCategory,
        ),
    ]);
  }

  // Ogni reparto ha una chiave fissa: durante il trascinamento quello
  // d'origine resta lo stesso widget e la casella trascinata non si smonta
  List<Widget> _buildCategories(BuildContext context) {
    final arranging = _arrangingItem;
    final arrangement = _arrangement;
    final grids = <Widget>[];
    for (int i = 0; i < widget.categories.length + 1; i++) {
      final Category? category =
          i < widget.categories.length ? widget.categories[i] : null;
      final name =
          category?.name ?? AppLocalizations.of(context)!.uncategorized;
      final key = ValueKey('category-${category?.id}');

      if (arranging != null && arranging.category != category) {
        grids.add(SliverCategoryDropHeader(
          key: key,
          name: name,
          onDrop: (item) => widget.onMoveToCategory?.call(item, category),
        ));
        continue;
      }

      final items =
          widget.shoppingList?.items.where((e) => e.category == category) ??
              const <ShoppinglistItem>[];
      if (items.isEmpty) continue;
      grids.add(SliverCategoryItemGridList<ShoppinglistItem>(
        key: key,
        name: name,
        items: items.toList(),
        categories: widget.categories,
        shoppingList: widget.shoppingList,
        selected: _isSelected,
        isLoading: widget.isLoading,
        onRefresh: widget.onRefresh,
        onPressed: widget.onPressed,
        onLongPressed: widget.onLongPressed,
        shoppingListStyle: widget.shoppingListStyle,
        arrangement: arrangement,
      ));
    }
    return grids;
  }
}
