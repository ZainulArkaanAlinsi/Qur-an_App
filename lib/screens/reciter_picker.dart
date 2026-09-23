import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/models/reciter.dart';

/// Menyaring daftar qari dengan kata kunci.
///
/// Dipisah sebagai fungsi murni supaya bisa diuji tanpa membuka sheet-nya.
/// Mencocokkan nama Latin maupun nama Arab, tanpa peduli besar kecil huruf.
List<Reciter> filterReciters(List<Reciter> all, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return all;
  return [
    for (final reciter in all)
      if (reciter.englishName.toLowerCase().contains(needle) ||
          reciter.name.toLowerCase().contains(needle) ||
          reciter.identifier.toLowerCase().contains(needle))
        reciter,
  ];
}

/// Mengelompokkan qari menurut gaya bacaannya, urut sesuai [RecitationStyle].
///
/// Kelompok kosong tidak disertakan, jadi daftar yang seluruhnya satu gaya
/// tidak menampilkan judul kelompok yang tidak berguna.
Map<RecitationStyle, List<Reciter>> groupReciters(List<Reciter> all) {
  final groups = <RecitationStyle, List<Reciter>>{};
  for (final style in RecitationStyle.values) {
    final members = [
      for (final reciter in all)
        if (reciter.style == style) reciter,
    ];
    if (members.isNotEmpty) groups[style] = members;
  }
  return groups;
}

/// Sheet pemilih qari: ada pencarian, dikelompokkan per gaya bacaan, dan tiap
/// baris bisa dicoba dengar sebelum dipilih.
Future<Reciter?> showReciterPicker(
  BuildContext context, {
  required List<Reciter> reciters,
  required Reciter selected,
  required void Function(Reciter reciter) onPreview,
}) => showModalBottomSheet<Reciter>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _ReciterPicker(
    reciters: reciters,
    selected: selected,
    onPreview: onPreview,
  ),
);

class _ReciterPicker extends StatefulWidget {
  const _ReciterPicker({
    required this.reciters,
    required this.selected,
    required this.onPreview,
  });

  final List<Reciter> reciters;
  final Reciter selected;
  final void Function(Reciter reciter) onPreview;

  @override
  State<_ReciterPicker> createState() => _ReciterPickerState();
}

class _ReciterPickerState extends State<_ReciterPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final matches = filterReciters(widget.reciters, _query);
    final groups = groupReciters(matches);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pilih qari',
                      style: SacredText.listName.copyWith(color: tokens.ink),
                    ),
                  ),
                  Text(
                    '${matches.length} dari ${widget.reciters.length}',
                    style: SacredText.cardNote.copyWith(color: tokens.sec),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: tokens.fill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    LineIcon(
                      SacredIcons.search,
                      color: tokens.sec,
                      size: 18,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (value) => setState(() => _query = value),
                        style: SacredText.searchInput.copyWith(
                          color: tokens.ink,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Cari nama qari',
                          hintStyle: SacredText.searchInput.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Tidak ada qari yang cocok dengan "$_query".',
                          textAlign: TextAlign.center,
                          style: SacredText.body.copyWith(color: tokens.sec),
                        ),
                      ),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final entry in groups.entries) ...[
                          _GroupHeader(style: entry.key),
                          for (final reciter in entry.value)
                            _ReciterRow(
                              reciter: reciter,
                              isSelected:
                                  reciter.identifier ==
                                  widget.selected.identifier,
                              onPreview: () => widget.onPreview(reciter),
                              onPick: () => Navigator.pop(context, reciter),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.style});

  final RecitationStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            style.label.toUpperCase(),
            style: SacredText.eyebrow.copyWith(color: tokens.goldText),
          ),
          const SizedBox(height: 2),
          Text(
            style.description,
            style: SacredText.cardNote.copyWith(color: tokens.sec),
          ),
        ],
      ),
    );
  }
}

class _ReciterRow extends StatelessWidget {
  const _ReciterRow({
    required this.reciter,
    required this.isSelected,
    required this.onPreview,
    required this.onPick,
  });

  final Reciter reciter;
  final bool isSelected;
  final VoidCallback onPreview;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ListTile(
      leading: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? tokens.primaryText : tokens.sec,
      ),
      title: Text(reciter.displayName),
      subtitle: Text(
        reciter.name.isEmpty ? reciter.identifier : reciter.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Mendengar contoh dulu jauh lebih berguna daripada menebak dari nama.
      trailing: IconButton(
        tooltip: 'Dengar contoh',
        onPressed: onPreview,
        icon: const Icon(Icons.play_circle_outline_rounded),
      ),
      selected: isSelected,
      onTap: onPick,
    );
  }
}
