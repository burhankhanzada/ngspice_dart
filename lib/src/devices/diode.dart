import 'dart:math' as math;

import '../numeric/complex.dart';
import 'device.dart';

/// Parameters for a diode model (a small, practical subset of the SPICE `.model
/// D` card).
class DiodeModel {
  final double isat; // saturation current (IS)
  final double n; // emission coefficient (N)
  final double rs; // series resistance (RS) -- reserved, not yet stamped
  final double temp; // temperature in Kelvin

  const DiodeModel({
    this.isat = 1e-14,
    this.n = 1.0,
    this.rs = 0.0,
    this.temp = 300.15,
  });

  /// Thermal voltage kT/q.
  double get vt => 1.380649e-23 * temp / 1.602176634e-19;
}

/// Junction diode (anode [a], cathode [c]) using the Shockley equation, solved
/// with Newton-Raphson. Implements the classic `pnjlim` voltage limiting for
/// robust convergence and a small `gmin` shunt to keep the matrix non-singular.
class Diode extends Device {
  final int a;
  final int c;
  final DiodeModel model;
  final double gmin;

  // Newton state: the limited junction voltage from the previous iteration.
  double _vdPrev = 0.0;
  bool _started = false;

  // Linearised conductance at the operating point, reused by AC analysis.
  double _gOp = 0.0;

  Diode(super.name, this.a, this.c, this.model, {this.gmin = 1e-12});

  @override
  bool get isNonlinear => true;

  @override
  void stamp(StampContext ctx) {
    final vt = model.vt;
    final nvt = model.n * vt;

    final vRaw = ctx.v(a) - ctx.v(c);
    var vd = vRaw;

    if (_started) {
      vd = _limitJunction(vd, _vdPrev, vt, nvt);
      if ((vd - vRaw).abs() > 1e-12) {
        // Limiting altered the junction voltage: the solution is not yet
        // consistent, so signal the Newton loop to keep iterating.
        ctx.limited = true;
      }
    } else {
      _started = true;
      ctx.limited = true; // first evaluation is never a converged point
    }
    _vdPrev = vd;

    // Shockley current and its derivative, with a gmin shunt.
    final ex = math.exp(vd / nvt);
    final id = model.isat * (ex - 1.0) + gmin * vd;
    final gd = (model.isat / nvt) * ex + gmin;
    _gOp = gd;

    final ieq = id - gd * vd;
    ctx.mna.stampConductance(a, c, gd);
    ctx.mna.stampCurrentSource(a, c, ieq);
  }

  @override
  void stampAc(AcStampContext ctx) {
    ctx.mna.stampAdmittance(a, c, Complex.real(_gOp));
  }

  /// Classic pnjlim limiting to bound the per-iteration change in junction
  /// voltage and prevent `exp` overflow.
  double _limitJunction(double vnew, double vold, double vt, double nvt) {
    final vcrit = nvt * math.log(nvt / (math.sqrt2 * model.isat));
    if (vnew > vcrit && (vnew - vold).abs() > 2 * nvt) {
      if (vold > 0) {
        final arg = 1 + (vnew - vold) / nvt;
        vnew = arg > 0 ? vold + nvt * math.log(arg) : vcrit;
      } else {
        vnew = vnew > 0 ? nvt * math.log(vnew / nvt) : vnew;
      }
    }
    return vnew;
  }

  @override
  void reset() {
    _vdPrev = 0.0;
    _started = false;
    _gOp = 0.0;
  }
}
