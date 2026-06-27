/// Parses SPICE-style numeric values with engineering suffixes.
///
/// SPICE recognises the scale factors below. Matching is case-insensitive and
/// any trailing alphabetic characters after a recognised suffix are ignored
/// (so `10kohm`, `1uF`, `2.2nF` all parse). Note `meg` must be tested before
/// `m`, since both start with `m`.
class SpiceValue {
  /// Ordered longest-first so that e.g. `meg` wins over `m`.
  static const List<MapEntry<String, double>> _suffixes = [
    MapEntry('meg', 1e6),
    MapEntry('mil', 25.4e-6),
    MapEntry('t', 1e12),
    MapEntry('g', 1e9),
    MapEntry('k', 1e3),
    MapEntry('m', 1e-3),
    MapEntry('u', 1e-6),
    MapEntry('n', 1e-9),
    MapEntry('p', 1e-12),
    MapEntry('f', 1e-15),
  ];

  /// Parses [token] into a double, or returns null if it is not numeric.
  static double? tryParse(String token) {
    var s = token.trim();
    if (s.isEmpty) return null;

    // Strip a leading sign for separate handling.
    var sign = 1.0;
    if (s.startsWith('+')) {
      s = s.substring(1);
    } else if (s.startsWith('-')) {
      sign = -1.0;
      s = s.substring(1);
    }
    if (s.isEmpty) return null;

    // Find the boundary between the numeric mantissa (incl. exponent) and any
    // trailing suffix/unit text.
    final lower = s.toLowerCase();
    final mantissaEnd = _mantissaEnd(lower);
    if (mantissaEnd == 0) return null;

    final mantissa = double.tryParse(s.substring(0, mantissaEnd));
    if (mantissa == null) return null;

    var scale = 1.0;
    if (mantissaEnd < lower.length) {
      final rest = lower.substring(mantissaEnd);
      for (final e in _suffixes) {
        if (rest.startsWith(e.key)) {
          scale = e.value;
          break;
        }
      }
      // Unrecognised trailing text (e.g. a bare unit like "ohm") is ignored.
    }
    return sign * mantissa * scale;
  }

  /// Returns the index where the numeric mantissa (digits, decimal point and a
  /// valid `e+/-NN` exponent) ends.
  static int _mantissaEnd(String lower) {
    var i = 0;
    var seenDigit = false;
    // Integer/fraction part.
    while (i < lower.length) {
      final c = lower[i];
      if (_isDigit(c)) {
        seenDigit = true;
        i++;
      } else if (c == '.') {
        i++;
      } else {
        break;
      }
    }
    if (!seenDigit) return 0;

    // Optional exponent: only consume if it is a well-formed `e[+-]?digits`.
    if (i < lower.length && lower[i] == 'e') {
      var j = i + 1;
      if (j < lower.length && (lower[j] == '+' || lower[j] == '-')) j++;
      var expDigits = 0;
      while (j < lower.length && _isDigit(lower[j])) {
        j++;
        expDigits++;
      }
      if (expDigits > 0) i = j;
    }
    return i;
  }

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}
