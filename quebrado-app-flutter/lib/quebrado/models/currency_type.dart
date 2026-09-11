enum CurrencyType {
  usd,
  bsBCV,
  eur;

  String get value {
    switch (this) {
      case CurrencyType.usd:
        return "USD";
      case CurrencyType.bsBCV:
        return "Bs. BCV";
      case CurrencyType.eur:
        return "EUR";
    }
  }

  String get symbol {
    switch (this) {
      case CurrencyType.usd:
        return "\$";
      case CurrencyType.bsBCV:
        return "Bs.";
      case CurrencyType.eur:
        return "€";
    }
  }

  static CurrencyType fromString(String val) {
    if (val == "Bs. BCV" || val == "bsBCV" || val == "VES" || val == "Bs.") {
      return CurrencyType.bsBCV;
    }
    if (val == "EUR" || val == "eur" || val == "€") {
      return CurrencyType.eur;
    }
    return CurrencyType.usd;
  }
}
