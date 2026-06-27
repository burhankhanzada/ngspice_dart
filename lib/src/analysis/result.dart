import '../numeric/complex.dart';

/// Holds the output vectors produced by one analysis run (a "plot" in ngspice
/// terminology). Real analyses (OP/DC/TRAN) fill [realVectors]; AC fills
/// [complexVectors]. Lookups are case-insensitive.
class SimResult {
  /// e.g. 'tran1', 'op1', 'dc1', 'ac1'.
  final String name;

  /// Human label of the independent variable, e.g. 'time', 'frequency', or the
  /// swept source name.
  final String sweepName;

  final List<double> sweep = [];
  final Map<String, List<double>> _real = {};
  final Map<String, List<Complex>> _complex = {};

  SimResult(this.name, this.sweepName);

  void setRealVector(String key, List<double> data) {
    _real[key.toLowerCase()] = data;
  }

  void setComplexVector(String key, List<Complex> data) {
    _complex[key.toLowerCase()] = data;
  }

  List<double>? realVector(String key) => _real[key.toLowerCase()];
  List<Complex>? complexVector(String key) => _complex[key.toLowerCase()];

  /// Returns a real vector for [key]. For complex (AC) data, returns the
  /// magnitude so callers expecting `List<double>` still get useful values.
  List<double>? asReal(String key) {
    final r = _real[key.toLowerCase()];
    if (r != null) return r;
    final c = _complex[key.toLowerCase()];
    if (c != null) return c.map((e) => e.abs).toList();
    return null;
  }

  Iterable<String> get realVectorNames => _real.keys;
  Iterable<String> get complexVectorNames => _complex.keys;
}
