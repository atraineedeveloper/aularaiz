enum WritingLevel { presyllabic, syllabic, syllabicAlphabetic, alphabetic }

extension WritingLevelLabels on WritingLevel {
  String get spanishLabel {
    return switch (this) {
      WritingLevel.presyllabic => 'Presilábico',
      WritingLevel.syllabic => 'Silábico',
      WritingLevel.syllabicAlphabetic => 'Silábico-alfabético',
      WritingLevel.alphabetic => 'Alfabético',
    };
  }
}
