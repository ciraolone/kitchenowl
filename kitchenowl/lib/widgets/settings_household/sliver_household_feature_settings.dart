import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/household_add_update/household_add_update_cubit.dart';
import 'package:kitchenowl/enums/views_enum.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:reorderables/reorderables.dart';

import 'view_settings_list_tile.dart';

class SliverHouseholdFeatureSettings<
    Cubit extends HouseholdAddUpdateCubit<State>,
    State extends HouseholdAddUpdateState> extends StatelessWidget {
  const SliverHouseholdFeatureSettings({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: BlocBuilder<Cubit, State>(
            builder: (context, state) => Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.features}:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 40),
                if (!listEquals(state.viewOrdering, ViewsEnum.values))
                  IconButton(
                    onPressed: BlocProvider.of<Cubit>(context).resetViewOrder,
                    tooltip: AppLocalizations.of(context)!.reset,
                    icon: const Icon(Icons.restart_alt_rounded),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ),
        BlocBuilder<Cubit, State>(
          builder: (context, state) => ReorderableColumn(
            onReorder: BlocProvider.of<Cubit>(context).reorderView,
            children: state.viewOrdering
                .sublist(0, state.viewOrdering.length - 1)
                .map(
                  (view) => ViewSettingsListTile<Cubit>(
                    key: ValueKey(view),
                    view: view,
                    isActive: state.isViewActive(view),
                  ),
                )
                .toList(),
          ),
        ),
        Center(child: Text(AppLocalizations.of(context)!.longPressToReorder)),
        const SizedBox(height: 8),
      ]),
    );
  }
}
