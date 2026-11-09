import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_extensions.dart';
import '../models/place_model.dart';
import '../providers/transport_provider.dart';
import '../repo/transport_repository.dart';
import '../../../core/l10n/language.dart';

/// "Search a place": type a name, pick one of the matches.
class PlaceSearchField extends ConsumerStatefulWidget {
  final ValueChanged<PlaceModel> onPicked;

  const PlaceSearchField({super.key, required this.onPicked});

  @override
  ConsumerState<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<PlaceSearchField> {
  final _text = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _text.text.trim();
    if (text.length < 2) return;

    setState(() => _searching = true);
    List<PlaceModel> places;
    try {
      places = await ref.read(transportActionsProvider).searchPlaces(text);
    } on TransportException catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        context.showMessage(e.message);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _searching = false);

    if (places.isEmpty) {
      context.showMessage(
        tr('Nothing found. Try another name, or tap the map.'),
      );
      return;
    }

    final picked = await showModalBottomSheet<PlaceModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in places)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name),
                subtitle: Text(
                  p.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _text.clear();
    widget.onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        hintText: tr('Search a place, e.g. Al-Yarmouk hospital'),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: tr('Search'),
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward),
              ),
      ),
    );
  }
}
