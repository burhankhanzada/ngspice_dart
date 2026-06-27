import 'dart:math' as math;
import 'dart:typed_data';

import '../circuit/circuit.dart';
import '../circuit/mna.dart';
import '../devices/device.dart';

/// Thrown when Newton-Raphson fails to converge.
class ConvergenceException implements Exception {
  final String message;
  ConvergenceException(this.message);
  @override
  String toString() => 'ConvergenceException: $message';
}

/// Solves a single real-valued operating point (the inner Newton-Raphson loop
/// shared by OP, DC-sweep steps and each transient time point).
class DcSolver {
  final Circuit circuit;
  final IntegrationMethod integration;

  /// Convergence tolerances (ngspice defaults).
  final double reltol;
  final double abstol; // current tolerance
  final double vntol; // voltage tolerance
  final int maxIterations;

  late final Mna _mna = Mna(circuit.systemSize);
  late final bool _hasNonlinear = circuit.devices.any((d) => d.isNonlinear);

  DcSolver(
    this.circuit, {
    this.integration = IntegrationMethod.trapezoidal,
    this.reltol = 1e-3,
    this.abstol = 1e-12,
    this.vntol = 1e-6,
    this.maxIterations = 100,
  });

  /// Returns the converged solution vector (node voltages then branch
  /// currents). [guess] warm-starts the Newton iteration.
  Float64List solve({
    required AnalysisMode mode,
    double time = 0,
    double timeStep = 0,
    Float64List? guess,
  }) {
    final size = circuit.systemSize;
    var x = guess != null ? Float64List.fromList(guess) : Float64List(size);

    final maxIter = _hasNonlinear ? maxIterations : 2;

    for (var iter = 0; iter < maxIter; iter++) {
      _mna.reset();
      final ctx = StampContext(
        mna: _mna,
        mode: mode,
        time: time,
        timeStep: timeStep,
        integration: integration,
        solution: x,
        nodeCount: circuit.nodeCount,
      );
      for (final d in circuit.devices) {
        d.stamp(ctx);
      }

      final xNew = _mna.solve();

      if (!ctx.limited && iter > 0 && _converged(x, xNew)) {
        return xNew;
      }
      x = xNew;
    }

    if (_hasNonlinear) {
      throw ConvergenceException(
          'Newton-Raphson did not converge in $maxIterations iterations '
          '(mode=$mode, t=$time)');
    }
    return x;
  }

  bool _converged(Float64List prev, Float64List next) {
    for (var i = 0; i < next.length; i++) {
      final tol = reltol * math.max(prev[i].abs(), next[i].abs()) + vntol;
      if ((next[i] - prev[i]).abs() > tol) return false;
    }
    return true;
  }
}
