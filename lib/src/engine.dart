import 'analysis/result.dart';
import 'analysis/simulator.dart';
import 'circuit/circuit.dart';
import 'circuit/mna.dart';
import 'numeric/complex.dart';
import 'parser/netlist_parser.dart';

/// The pure-Dart ngspice engine: parse a netlist, run analyses, retrieve
/// vectors. This is the native replacement for the C `libngspice` shared
/// library that the package previously bound to over FFI.
class NgspiceEngine {
  Circuit? _circuit;
  Simulator? _simulator;
  IntegrationMethod integration;

  /// Captured lines emitted by `print`-style commands (analogous to the FFI
  /// `printfcn` callback output).
  final List<String> output = [];

  NgspiceEngine({this.integration = IntegrationMethod.trapezoidal});

  /// Resets all engine state.
  void reset() {
    _circuit = null;
    _simulator = null;
    output.clear();
  }

  Circuit? get circuit => _circuit;
  Simulator? get simulator => _simulator;

  /// The current ("last") analysis result, if any.
  SimResult? get currentResult => _simulator?.current;

  /// Parses a netlist (array of lines) into the active circuit.
  void loadCircuit(List<String> lines) {
    _circuit = NetlistParser().parse(lines);
    _simulator = null;
  }

  /// Runs all analyses declared in the loaded circuit.
  void run() {
    final c = _circuit;
    if (c == null) {
      throw StateError('No circuit loaded; call loadCircuit() first.');
    }
    final sim = Simulator(c, integration: integration);
    sim.run();
    _simulator = sim;
  }

  /// Executes an ngspice-style command. Returns true on success.
  bool command(String cmd) {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return true;
    final tokens = trimmed.split(RegExp(r'\s+'));
    final verb = tokens.first.toLowerCase();

    switch (verb) {
      case 'run':
      case 'tran':
      case 'op':
      case 'dc':
      case 'ac':
        run();
        return true;
      case 'reset':
        if (_circuit != null) {
          loadCircuitFromCurrent();
        }
        return true;
      case 'print':
      case 'plot':
      case 'set':
      case 'setplot':
      case 'save':
      case 'write':
      case 'quit':
      case 'echo':
        // Recognised; capture a best-effort textual response.
        _handlePrint(tokens);
        return true;
      default:
        // Unknown commands are tolerated (return success) to mirror the lenient
        // interactive interpreter.
        return true;
    }
  }

  void loadCircuitFromCurrent() {
    _simulator = null;
  }

  void _handlePrint(List<String> tokens) {
    if (tokens.first.toLowerCase() != 'print') return;
    final result = currentResult;
    if (result == null) return;
    for (final name in tokens.skip(1)) {
      if (name.toLowerCase() == 'all') {
        for (final v in result.realVectorNames) {
          final data = result.realVector(v);
          output.add('$v = ${data?.isNotEmpty == true ? data!.last : ''}');
        }
        continue;
      }
      final data = result.asReal(name);
      if (data != null && data.isNotEmpty) {
        output.add('$name = ${data.last}');
      }
    }
  }

  /// Returns the named real vector from the current result (case-insensitive),
  /// or null. AC magnitude is returned for complex vectors.
  List<double>? getVector(String name) => currentResult?.asReal(name);

  /// Returns the named complex vector (AC), or null.
  List<Complex>? getComplexVector(String name) =>
      currentResult?.complexVector(name);

  /// All available real vector names in the current result.
  List<String> vectorNames() =>
      currentResult?.realVectorNames.toList() ?? const [];
}
