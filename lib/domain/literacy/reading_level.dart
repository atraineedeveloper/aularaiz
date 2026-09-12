enum ReadingLevel { doesNotRead, syllabic, wordByWord, sentence, fluent }

extension ReadingLevelLabels on ReadingLevel {
  String get spanishLabel {
    return switch (this) {
      ReadingLevel.doesNotRead => 'No lee',
      ReadingLevel.syllabic => 'Silábico',
      ReadingLevel.wordByWord => 'Palábrico',
      ReadingLevel.sentence => 'Oracional',
      ReadingLevel.fluent => 'Fluido',
    };
  }
}
