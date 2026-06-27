import 'dart:typed_data';

import '../circuit/mna.dart';
import '../numeric/complex.dart';

/// Context handed to a device when it stamps the real (OP/DC/transient) system.
class StampContext {
  final Mna mna;
  final AnalysisMode mode;

  /// Current simulation time (transient only; 0 otherwise).
  final double time;

  /// Current transient time step `h`; 0 for OP/DC.
  final double timeStep;

  /// Integration rule for reactive companion models.
  final IntegrationMethod integration;

  /// Latest Newton iterate of the full solution vector (node voltages then
  /// branch currents). Used by nonlinear devices to linearise around the
  /// present guess.
  final Float64List solution;

  /// Total node count, so branch indices can be interpreted if needed.
  final int nodeCount;

  /// Set by a nonlinear device when it applied voltage/current limiting this
  /// iteration. The Newton loop must not declare convergence while limiting is
  /// active, because the linearisation point still lags the true solution.
  bool limited = false;

  StampContext({
    required this.mna,
    required this.mode,
    required this.time,
    required this.timeStep,
    required this.integration,
    required this.solution,
    required this.nodeCount,
  });

  /// Voltage of node [idx] in the current Newton iterate (0 for ground).
  double v(int idx) => idx < 0 ? 0.0 : solution[idx];

  /// Value of branch unknown [idx] (a full system index).
  double branch(int idx) => idx < 0 ? 0.0 : solution[idx];
}

/// Context for AC small-signal stamping.
class AcStampContext {
  final AcMna mna;

  /// Angular frequency in rad/s.
  final double omega;

  AcStampContext({required this.mna, required this.omega});

  Complex get jOmega => Complex(0, omega);
}

/// Base class for all circuit elements.
///
/// Lifecycle:
///  1. Constructed by the parser with resolved node indices.
///  2. [branchCount] is queried; the circuit assigns [branchBase].
///  3. For each solve, [stamp] (or [stampAc]) is called one or more times
///     (multiple times within a Newton loop for nonlinear devices).
///  4. After a transient step converges, [acceptTimestep] records history.
abstract class Device {
  /// Instance name including the type prefix, e.g. `R1`, `C1`, `V1`.
  final String name;

  Device(this.name);

  /// Number of extra branch-current unknowns this device adds to the system.
  int get branchCount => 0;

  /// First branch index assigned to this device (a full system index), or -1
  /// if the device uses no branches.
  int branchBase = -1;

  /// True if the device must be solved with Newton-Raphson iterations.
  bool get isNonlinear => false;

  /// Stamps the real system for OP / DC / transient analysis.
  void stamp(StampContext ctx);

  /// Stamps the complex system for AC analysis. The DC operating point has
  /// already been computed and is available to nonlinear devices via their
  /// stored linearisation. Default: no contribution.
  void stampAc(AcStampContext ctx) {}

  /// Records post-step state (e.g. capacitor voltage / inductor current) once a
  /// transient time point has converged. [solution] is the accepted solution.
  void acceptTimestep(Float64List solution, double time, double timeStep) {}

  /// Resets any stored transient/operating-point history.
  void reset() {}
}
