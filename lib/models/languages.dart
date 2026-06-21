enum Language {
  pt,
  en;

  String get label {
    return switch (this) {
      .pt => 'Português',
      .en => 'Inglês',
    };
  }
}
