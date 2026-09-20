class SurahMeta {
  const SurahMeta(this.number, this.name, this.ayahCount, this.revelation);
  final int number;
  final String name;
  final int ayahCount;
  final String revelation;

  String get displayName => name
      .replaceAll('â€™', '’')
      .replaceAll('â€˜', '‘')
      .replaceAll('â€“', '–')
      .replaceAll('Â·', '·');
}
