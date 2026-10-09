/// Riga di un reparto su cui lasciare qualcosa di trascinato: un articolo
/// (feature 004-riordino-trascinamento del fork di Andrea) o un altro reparto
/// (feature 005-reparti-dalla-lista). Nell'ordinamento per reparti, durante un
/// trascinamento, prende il posto dei reparti, anche di quelli senza articoli
/// in lista; si illumina quando ci passa sopra qualcosa che accetta e al
/// rilascio chiama onDrop. Senza onDrop non accetta nulla: è la riga sbiadita
/// del reparto che si sta trascinando. onMove riceve ogni spostamento sopra la
/// riga, accettato o no: la vista lo usa per lo scorrimento ai bordi quando
/// il pezzo trascinato non riceve più gli spostamenti del dito. CategoryRow è
/// l'aspetto della riga, usato anche per il reparto che segue il dito.
library;

import 'package:flutter/material.dart';

class SliverCategoryDropHeader<T extends Object> extends StatelessWidget {
  final String name;
  final void Function(T dropped)? onDrop;
  final void Function(DragTargetDetails<T> details)? onMove;

  /// Chiave della riga visibile, per chi deve sapere dove sta sullo schermo.
  final Key? rowKey;

  const SliverCategoryDropHeader({
    super.key,
    required this.name,
    this.onDrop,
    this.onMove,
    this.rowKey,
  });

  @override
  Widget build(BuildContext context) {
    final onDrop = this.onDrop;

    return SliverToBoxAdapter(
      child: DragTarget<T>(
        onWillAcceptWithDetails: (details) => onDrop != null,
        onAcceptWithDetails: (details) => onDrop?.call(details.data),
        onMove: onMove,
        builder: (context, candidates, rejected) => CategoryRow(
          key: rowKey,
          name: name,
          isHighlighted: candidates.isNotEmpty,
          isFaded: onDrop == null,
        ),
      ),
    );
  }
}

class CategoryRow extends StatelessWidget {
  final String name;
  final bool isHighlighted;
  final bool isFaded;

  const CategoryRow({
    super.key,
    required this.name,
    this.isHighlighted = false,
    this.isFaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isFaded ? 0.4 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isHighlighted
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(name, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
