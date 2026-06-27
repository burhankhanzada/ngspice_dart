import '../circuit/circuit.dart';
import '../circuit/mna.dart';
import '../devices/device.dart';
import '../numeric/complex.dart';

/// Small-signal AC analysis. Assumes nonlinear devices have already been
/// linearised at the DC operating point (their `stampAc` uses the stored
/// operating-point conductances). Builds and solves one complex MNA system per
/// frequency.
class AcAnalysis {
  final Circuit circuit;
  late final AcMna _mna = AcMna(circuit.systemSize);

  AcAnalysis(this.circuit);

  /// Solves the network at angular frequency [omega] (rad/s) and returns the
  /// complex solution vector (node voltages then branch currents).
  List<Complex> solveAt(double omega) {
    _mna.reset();
    final ctx = AcStampContext(mna: _mna, omega: omega);
    for (final d in circuit.devices) {
      d.stampAc(ctx);
    }
    return _mna.solve();
  }
}
