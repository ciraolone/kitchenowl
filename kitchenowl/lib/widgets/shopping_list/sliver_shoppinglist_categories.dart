/// Articoli in lista divisi per reparto, con i due trascinamenti fra reparti.
/// Trascinando un articolo (feature 004-riordino-trascinamento del fork di
/// Andrea) il suo reparto resta aperto e gli altri diventano righe su cui
/// lasciarlo, compresi quelli vuoti e Uncategorized. Trascinando il nome di un
/// reparto (feature 005-reparti-dalla-lista) tutti i reparti diventano righe,
/// anche quelli vuoti, e lasciandolo su una riga prende quel posto;
/// Uncategorized non si trascina e in quel momento non compare, perché sta
/// sempre in fondo. Lo stato dei due trascinamenti vive qui.
library;

import 'package:flutter/material.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/widgets/home_page/sliver_category_item_grid_list.dart';
import 'package:kitchenowl/widgets/shopping_list/arrangeable_category_title.dart';
import 'package:kitchenowl/widgets/shopping_list/arrangeable_item.dart';
import 'package:kitchenowl/widgets/shopping_list/category_drag_scroll.dart';
import 'package:kitchenowl/widgets/shopping_list/sliver_category_drop_header.dart';

class SliverShoppinglistCategories extends StatefulWidget {
  final ShoppingList? shoppingList;
  final List<Category> categories;
  final bool Function(ShoppinglistItem) selected;
  final bool isLoading;
  final void Function()? onRefresh;
  final Nullable<void Function(ShoppinglistItem)>? onPressed;
  final Nullable<void Function(ShoppinglistItem)>? onLongPressed;
  final ShoppingListStyle shoppingListStyle;
  final void Function(ShoppinglistItem moved, ShoppinglistItem target)?
      onArrange;
  final void Function(ShoppinglistItem moved, Category? category)?
      onMoveToCategory;
  final void Function(Category moved, Category target)? onArrangeCategory;

  const SliverShoppinglistCategories({
    super.key,
    this.shoppingList,
    required this.categories,
    required this.selected,
    required this.isLoading,
    this.onRefresh,
    this.onPressed,
    this.onLongPressed,
    required this.shoppingListStyle,
    this.onArrange,
    this.onMoveToCategory,
    this.onArrangeCategory,
  });

  @override
  State<SliverShoppinglistCategories> createState() =>
      _SliverShoppinglistCategoriesState();
}

class _SliverShoppinglistCategoriesState
    extends State<SliverShoppinglistCategories> {
  ShoppinglistItem? _arrangingItem;
  Category? _arrangingCategory;
  final _categoryDragScroll = CategoryDragScroll();

  ItemArrangement<ShoppinglistItem>? get _arrangement {
    final onArrange = widget.onArrange;
    if (onArrange == null || widget.onMoveToCategory == null) return null;
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
    final arrangingCategory = _arrangingCategory;
    final List<Widget> slivers = arrangingCategory != null
        ? [
            for (final category in widget.categories)
              _buildCategoryRow(context, category, arrangingCategory),
          ]
        : [
            for (final category in [...widget.categories, null])
              _buildCategory(context, category),
          ].nonNulls.toList();
    return SliverMainAxisGroup(slivers: slivers);
  }

  Widget _buildCategoryRow(
    BuildContext context,
    Category category,
    Category arranging,
  ) {
    final isOrigin = isSameCategory(category, arranging);
    final onArrangeCategory = widget.onArrangeCategory;
    final width = MediaQuery.sizeOf(context).width;

    return SliverCategoryDropHeader<Category>(
      key: ValueKey('category-row-${category.id ?? category.name}'),
      rowKey: isOrigin ? _categoryDragScroll.originRowKey : null,
      name: category.name,
      onDrop: isOrigin || onArrangeCategory == null
          ? null
          : (moved) => onArrangeCategory(moved, category),
      onMove: (details) => _categoryDragScroll.follow(details.offset, width),
    );
  }

  // Ogni reparto ha una chiave fissa: durante il trascinamento di un articolo
  // quello d'origine resta lo stesso widget e la casella non si smonta
  Widget? _buildCategory(BuildContext context, Category? category) {
    final arranging = _arrangingItem;
    final name = category?.name ?? AppLocalizations.of(context)!.uncategorized;
    final key = ValueKey('category-${category?.id}');

    if (arranging != null && !isSameCategory(arranging.category, category)) {
      return SliverCategoryDropHeader<ShoppinglistItem>(
        key: key,
        name: name,
        onDrop: (item) => widget.onMoveToCategory?.call(item, category),
      );
    }

    final items = widget.shoppingList?.items
            .where((e) => isSameCategory(e.category, category))
            .toList() ??
        const <ShoppinglistItem>[];
    if (items.isEmpty) return null;
    return SliverCategoryItemGridList<ShoppinglistItem>(
      key: key,
      name: name,
      items: items,
      categories: widget.categories,
      shoppingList: widget.shoppingList,
      selected: widget.selected,
      isLoading: widget.isLoading,
      onRefresh: widget.onRefresh,
      onPressed: widget.onPressed,
      onLongPressed: widget.onLongPressed,
      shoppingListStyle: widget.shoppingListStyle,
      arrangement: _arrangement,
      wrapTitle: _arrangeableTitle(category),
    );
  }

  Widget Function(Widget title)? _arrangeableTitle(Category? category) {
    if (category == null || widget.onArrangeCategory == null) return null;
    return (title) => ArrangeableCategoryTitle(
          category: category,
          onStart: _startArrangingCategory,
          onEnd: _endArrangingCategory,
          child: title,
        );
  }

  void _startArrangingCategory(Category category, double fingerY) {
    setState(() => _arrangingCategory = category);
    _categoryDragScroll.start(Scrollable.of(context), fingerY);
  }

  void _endArrangingCategory() {
    _categoryDragScroll.stop();
    if (mounted) setState(() => _arrangingCategory = null);
  }
}
