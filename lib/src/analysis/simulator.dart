import 'dart:math' as math;
import 'dart:typed_data';

import '../circuit/circuit.dart';
import '../circuit/mna.dart';
import '../devices/capacitor.dart';
import '../devices/inductor.dart';
import '../devices/sources.dart';
import '../numeric/complex.dart';
import 'ac_analysis.dart';
import 'dc_solver.dart';
import 'result.dart';

/// Runs the analyses declared in a [Circuit] and accumulates labelled output
/// vectors. This is the pure-Dart equivalent of ngspice's analysis loop.
class Simulator {
  final Circuit circuit;
  final IntegrationMethod integration;

  final List<SimResult> results = [];

  Simulator(this.circuit, {this.integration = IntegrationMethod.trapezoidal});

  /// The most recent result ("current plot").
  SimResult? get current => results.isEmpty ? null : results.last;

  /// Runs every analysis directive in declaration order. If none is present,
  /// a bare operating point is computed.
  void run() {
    circuit.resetDevices();
    if (circuit.analyses.isEmpty) {
      _runOp();
      return;
    }
    var i = 0;
    for (final a in circuit.analyses) {
      i++;
      circuit.resetDevices();
      switch (a) {
        case OpDirective():
          _runOp(index: i);
        case TranDirective d:
          _runTran(d, index: i);
        case DcDirective d:
          _runDc(d, index: i);
        case AcDirective d:
          _runAc(d, index: i);
      }
    }
  }

  // --- Operating point -----------------------------------------------------

  void _runOp({int index = 1}) {
    final solver = DcSolver(circuit, integration: integration);
    final x = solver.solve(mode: AnalysisMode.operatingPoint);
    final result = SimResult('op$index', 'op');
    result.sweep.add(0);
    _storeSolutionColumn(result, x);
    results.add(result);
  }

  // --- DC sweep ------------------------------------------------------------

  void _runDc(DcDirective d, {int index = 1}) {
    final source = _findSource(d.source);
    if (source == null) {
      throw ArgumentError('.dc: unknown source "${d.source}"');
    }
    final result = SimResult('dc$index', d.source);
    final solver = DcSolver(circuit, integration: integration);

    final columns = <Float64List>[];
    Float64List? guess;
    final ascending = d.step > 0;
    for (var v = d.start;
        ascending ? v <= d.stop + d.step * 1e-9 : v >= d.stop + d.step * 1e-9;
        v += d.step) {
      source(v);
      final x = solver.solve(mode: AnalysisMode.dc, guess: guess);
      guess = x;
      result.sweep.add(v);
      columns.add(x);
      if (d.step == 0) break;
    }
    _storeColumns(result, columns);
    results.add(result);
  }

  // --- Transient -----------------------------------------------------------

  void _runTran(TranDirective d, {int index = 1}) {
    final solver = DcSolver(circuit, integration: integration);
    final result = SimResult('tran$index', 'time');
    final columns = <Float64List>[];

    final h = d.tstep <= 0 ? d.tstop / 100 : d.tstep;
    final hStep = (d.tmax > 0 && d.tmax < h) ? d.tmax : h;

    Float64List x;
    if (d.useInitialConditions) {
      // UIC: skip the operating point. Seed reactive element histories from
      // their declared initial conditions, then solve the rest of the network
      // at t=0 with a negligibly small step so capacitors/inductors are pinned
      // to their ICs (geq = C/h -> very large clamps the voltage). The result
      // is a consistent t=0 sample (e.g. source nodes take their real values)
      // without disturbing the IC histories (we do not accept this step).
      _applyInitialConditions();
      final seed = Float64List(circuit.systemSize);
      _seedInitialNodeVoltages(seed);
      x = solver.solve(
        mode: AnalysisMode.transient,
        time: d.tstart,
        timeStep: hStep * 1e-9,
        guess: seed,
      );
    } else {
      // Quiescent operating point seeds the transient; reactive elements take
      // their history from that converged solution.
      x = solver.solve(mode: AnalysisMode.operatingPoint);
      for (final dev in circuit.devices) {
        dev.acceptTimestep(x, 0, 0);
      }
    }

    var t = d.tstart;
    // Record the initial point.
    result.sweep.add(t);
    columns.add(x);

    var time = t + hStep;
    while (time <= d.tstop + hStep * 1e-9) {
      x = solver.solve(
        mode: AnalysisMode.transient,
        time: time,
        timeStep: hStep,
        guess: x,
      );
      for (final dev in circuit.devices) {
        dev.acceptTimestep(x, time, hStep);
      }
      if (time >= d.tstart) {
        result.sweep.add(time);
        columns.add(x);
      }
      time += hStep;
    }
    _storeColumns(result, columns);
    results.add(result);
  }

  void _applyInitialConditions() {
    for (final dev in circuit.devices) {
      if (dev is Capacitor && dev.initialVoltage != null) {
        dev.setInitialState(dev.initialVoltage!);
      } else if (dev is Inductor && dev.initialCurrent != null) {
        dev.setInitialState(dev.initialCurrent!);
      }
    }
    // Node-level .ic on capacitors: if a capacitor spans a node with an .ic and
    // the other terminal is ground, seed it.
    circuit.options.forEach((key, value) {
      if (!key.startsWith('ic.')) return;
      final node = key.substring(3);
      for (final dev in circuit.devices) {
        if (dev is Capacitor) {
          final n1 = circuit.indexOfNode(node);
          if (n1 != null && dev.n1 == n1 && dev.n2 < 0) {
            dev.setInitialState(value);
          }
        }
      }
    });
  }

  /// Seeds [x] node voltages from capacitor `ic=` values (referenced to ground)
  /// and `.ic v(node)=` cards, used as the UIC starting point.
  void _seedInitialNodeVoltages(Float64List x) {
    for (final dev in circuit.devices) {
      if (dev is Capacitor && dev.initialVoltage != null) {
        if (dev.n1 >= 0 && dev.n2 < 0) x[dev.n1] = dev.initialVoltage!;
        if (dev.n2 >= 0 && dev.n1 < 0) x[dev.n2] = -dev.initialVoltage!;
      }
    }
    circuit.options.forEach((key, value) {
      if (!key.startsWith('ic.')) return;
      final idx = circuit.indexOfNode(key.substring(3));
      if (idx != null && idx >= 0) x[idx] = value;
    });
  }

  // --- AC ------------------------------------------------------------------

  void _runAc(AcDirective d, {int index = 1}) {
    // AC needs the DC operating point first (to linearise nonlinear devices).
    final solver = DcSolver(circuit, integration: integration);
    solver.solve(mode: AnalysisMode.operatingPoint);

    final ac = AcAnalysis(circuit);
    final result = SimResult('ac$index', 'frequency');
    final freqs = _acFrequencies(d);
    final columns = <List<Complex>>[];
    for (final f in freqs) {
      final x = ac.solveAt(2 * math.pi * f);
      result.sweep.add(f);
      columns.add(x);
    }
    _storeComplexColumns(result, columns);
    results.add(result);
  }

  List<double> _acFrequencies(AcDirective d) {
    final out = <double>[];
    switch (d.type) {
      case AcSweepType.lin:
        if (d.points <= 1) {
          out.add(d.fStart);
        } else {
          final step = (d.fStop - d.fStart) / (d.points - 1);
          for (var i = 0; i < d.points; i++) {
            out.add(d.fStart + i * step);
          }
        }
      case AcSweepType.dec:
        final ratio = math.pow(10, 1 / d.points).toDouble();
        for (var f = d.fStart; f <= d.fStop * (1 + 1e-9); f *= ratio) {
          out.add(f);
        }
      case AcSweepType.oct:
        final ratio = math.pow(2, 1 / d.points).toDouble();
        for (var f = d.fStart; f <= d.fStop * (1 + 1e-9); f *= ratio) {
          out.add(f);
        }
    }
    return out;
  }

  // --- Vector labelling / storage ------------------------------------------

  /// Stores a single-column (OP) solution as length-1 vectors.
  void _storeSolutionColumn(SimResult result, Float64List x) {
    _storeColumns(result, [x]);
  }

  void _storeColumns(SimResult result, List<Float64List> columns) {
    final nPoints = columns.length;
    // Node voltages.
    final names = circuit.nodeNames;
    for (var i = 0; i < names.length; i++) {
      final data = List<double>.generate(nPoints, (p) => columns[p][i]);
      result.setRealVector(names[i], data);
      result.setRealVector('v(${names[i]})', data);
    }
    // Branch currents.
    for (final dev in circuit.devices) {
      if (dev.branchCount > 0 && dev.branchBase >= 0) {
        final idx = dev.branchBase;
        final data = List<double>.generate(nPoints, (p) => columns[p][idx]);
        result.setRealVector('i(${dev.name})', data);
        result.setRealVector('${dev.name}#branch', data);
      }
    }
  }

  void _storeComplexColumns(SimResult result, List<List<Complex>> columns) {
    final nPoints = columns.length;
    final names = circuit.nodeNames;
    for (var i = 0; i < names.length; i++) {
      final data = List<Complex>.generate(nPoints, (p) => columns[p][i]);
      result.setComplexVector(names[i], data);
      result.setComplexVector('v(${names[i]})', data);
    }
    for (final dev in circuit.devices) {
      if (dev.branchCount > 0 && dev.branchBase >= 0) {
        final idx = dev.branchBase;
        final data = List<Complex>.generate(nPoints, (p) => columns[p][idx]);
        result.setComplexVector('i(${dev.name})', data);
      }
    }
  }

  // --- Helpers -------------------------------------------------------------

  /// Finds an independent source by name and returns a setter for its swept DC
  /// value, or null if not found.
  void Function(double)? _findSource(String name) {
    final lower = name.toLowerCase();
    for (final dev in circuit.devices) {
      if (dev.name.toLowerCase() != lower) continue;
      if (dev is VoltageSource) {
        return (v) => dev.dcSweepValue = v;
      } else if (dev is CurrentSource) {
        return (v) => dev.dcSweepValue = v;
      }
    }
    return null;
  }
}
