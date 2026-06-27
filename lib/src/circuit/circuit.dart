import '../devices/device.dart';

/// A parsed circuit: the node namespace, the device list, and the analysis
/// directives extracted from the netlist.
class Circuit {
  /// Title line (first line of a deck) if present.
  String title = '';

  final List<Device> devices = [];

  /// Analysis directives (`.tran`, `.dc`, `.ac`, `.op`) in declaration order.
  final List<AnalysisDirective> analyses = [];

  /// Options collected from `.option`/`.options` cards.
  final Map<String, double> options = {};

  /// Node name (as written) -> matrix index. Ground is not stored here.
  final Map<String, int> _nodeIndex = {};

  /// Matrix index -> canonical node name, for result labelling.
  final List<String> _nodeNames = [];

  int _branchCount = 0;
  bool _built = false;

  static bool isGround(String name) =>
      name == '0' || name.toLowerCase() == 'gnd';

  /// Resolves a node name to its matrix index (-1 for ground), creating a new
  /// index on first sight.
  int node(String name) {
    if (isGround(name)) return -1;
    final existing = _nodeIndex[name];
    if (existing != null) return existing;
    final idx = _nodeNames.length;
    _nodeIndex[name] = idx;
    _nodeNames.add(name);
    return idx;
  }

  int get nodeCount => _nodeNames.length;
  List<String> get nodeNames => List.unmodifiable(_nodeNames);

  int get branchCount => _branchCount;

  /// Total number of unknowns in the MNA system.
  int get systemSize => nodeCount + _branchCount;

  void add(Device device) {
    _built = false;
    devices.add(device);
  }

  /// Assigns branch indices to devices that need them. Must be called once
  /// after all devices/nodes are known and before stamping.
  void build() {
    if (_built) return;
    var next = nodeCount;
    for (final d in devices) {
      if (d.branchCount > 0) {
        d.branchBase = next;
        next += d.branchCount;
      }
    }
    _branchCount = next - nodeCount;
    _built = true;
  }

  /// Index of a named node, or null if unknown. Ground maps to -1.
  int? indexOfNode(String name) {
    if (isGround(name)) return -1;
    return _nodeIndex[name];
  }

  void resetDevices() {
    for (final d in devices) {
      d.reset();
    }
  }
}

/// Base type for parsed analysis cards.
abstract class AnalysisDirective {}

class OpDirective extends AnalysisDirective {}

class TranDirective extends AnalysisDirective {
  final double tstep;
  final double tstop;
  final double tstart;
  final double tmax;
  final bool useInitialConditions; // UIC
  TranDirective(this.tstep, this.tstop,
      {this.tstart = 0, this.tmax = 0, this.useInitialConditions = false});
}

class DcDirective extends AnalysisDirective {
  final String source;
  final double start;
  final double stop;
  final double step;
  DcDirective(this.source, this.start, this.stop, this.step);
}

enum AcSweepType { dec, oct, lin }

class AcDirective extends AnalysisDirective {
  final AcSweepType type;
  final int points; // points per decade/octave, or total for lin
  final double fStart;
  final double fStop;
  AcDirective(this.type, this.points, this.fStart, this.fStop);
}
