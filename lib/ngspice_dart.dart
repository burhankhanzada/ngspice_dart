/// ngspice_dart — a pure-Dart SPICE circuit simulator.
///
/// This package began life as Dart FFI bindings to the C `libngspice` shared
/// library. It is now a **native Dart port**: netlist parsing, Modified Nodal
/// Analysis assembly, the Newton-Raphson nonlinear solver and the OP/DC/
/// transient/AC analyses all run in pure Dart with no native dependency.
///
/// The [Ngspice] facade keeps the original ergonomic API (`init`, `command`,
/// `circuit`, `getVector`) so existing code keeps working. For richer access to
/// the engine (multiple result plots, complex AC vectors, the parsed circuit),
/// use [NgspiceEngine] directly.
library;

import 'src/engine.dart';
import 'src/numeric/complex.dart';

export 'src/engine.dart' show NgspiceEngine;
export 'src/analysis/result.dart' show SimResult;
export 'src/analysis/simulator.dart' show Simulator;
export 'src/circuit/circuit.dart';
export 'src/circuit/mna.dart' show IntegrationMethod, AnalysisMode;
export 'src/numeric/complex.dart' show Complex;
export 'src/parser/netlist_parser.dart'
    show NetlistParser, NetlistParseException;
export 'src/parser/value_parser.dart' show SpiceValue;

/// High-level facade over [NgspiceEngine], API-compatible with the previous
/// FFI-backed implementation.
class Ngspice {
  final NgspiceEngine engine;

  Ngspice() : engine = NgspiceEngine();

  Ngspice.withEngine(this.engine);

  /// Initializes the engine. Returns 0 on success (matching the C API).
  int init() {
    engine.reset();
    return 0;
  }

  /// Executes an ngspice-style command (e.g. `run`, `print all`). Returns 0 on
  /// success.
  int command(String cmd) {
    try {
      return engine.command(cmd) ? 0 : 1;
    } catch (_) {
      return 1;
    }
  }

  /// Loads a circuit from an array of netlist lines. Returns 0 on success.
  int circuit(List<String> circArray) {
    try {
      engine.loadCircuit(circArray);
      return 0;
    } catch (_) {
      return 1;
    }
  }

  /// Returns the named real data vector from the current result, or null.
  List<double>? getVector(String vecName) => engine.getVector(vecName);

  /// Returns the named complex (AC) vector, or null.
  List<Complex>? getComplexVector(String vecName) =>
      engine.getComplexVector(vecName);

  /// Names of all available vectors in the current result.
  List<String> vectorNames() => engine.vectorNames();
}
