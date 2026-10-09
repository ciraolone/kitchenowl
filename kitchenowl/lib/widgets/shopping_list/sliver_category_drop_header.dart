/// Riga di un reparto su cui lasciare un articolo trascinato (feature
/// 004-riordino-trascinamento del fork di Andrea). Nell'ordinamento per
/// reparti, durante un trascinamento, prende il posto di ogni reparto tranne
/// quello da cui parte l'articolo, anche dei reparti senza articoli in lista;
/// si illumina quando l'articolo ci passa sopra e al rilascio chiama onDrop.
library;

import 'package:flutter/material.dart';
import 'package:kitchenowl/models/item.dart';

class SliverCategoryDropHeader extends StatelessWidget {
  final String name;
  final void Function(ShoppinglistItem item) onDrop;

  const SliverCategoryDropHeader({
    super.key,
    required this.name,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: DragTarget<ShoppinglistItem>(
        onAcceptWithDetails: (details) => onDrop(details.data),
        builder: (context, candidates, rejected) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: candidates.isEmpty
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(name, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}
