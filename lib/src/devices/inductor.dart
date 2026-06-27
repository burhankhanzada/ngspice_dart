import 'dart:typed_data';

import '../circuit/mna.dart';
import '../numeric/complex.dart';
import 'device.dart';

/// Linear inductor between [n1] and [n2]. Always introduces one branch-current
/// unknown (the inductor current, flowing n1 -> n2).
///
/// DC/OP: a short circuit (0 V across it).
/// Transient: companion model V = (L/h)(I - I_prev) (Backward-Euler) or the
/// trapezoidal equivalent.
/// AC: impedance jωL.
class Inductor extends Device {
  final int n1;
  final int n2;
  final double inductance;
  final double? initialCurrent;

  double _iPrev = 0.0;
  double _vPrev = 0.0;
  bool _historyValid = false;

  Inductor(super.name, this.n1, this.n2, this.inductance,
      {this.initialCurrent});

  @override
  int get branchCount => 1;

  int get _k => branchBase;

  @override
  void stamp(StampContext ctx) {
    final k = _k;
    // Node KCL contributions of the branch current.
    ctx.mna.stampMatrix(n1, k, 1.0);
    ctx.mna.stampMatrix(n2, k, -1.0);
    ctx.mna.stampMatrix(k, n1, 1.0);
    ctx.mna.stampMatrix(k, n2, -1.0);

    if (ctx.mode == AnalysisMode.operatingPoint ||
        ctx.mode == AnalysisMode.dc) {
      // Short circuit: V(n1) - V(n2) = 0. Nothing further to stamp.
      return;
    }

    final h = ctx.timeStep;
    if (h <= 0) return;

    if (ctx.integration == IntegrationMethod.trapezoidal && _historyValid) {
      final r = 2.0 * inductance / h;
      ctx.mna.stampMatrix(k, k, -r);
      ctx.mna.stampRhs(k, -r * _iPrev - _vPrev);
    } else {
      final r = inductance / h;
      ctx.mna.stampMatrix(k, k, -r);
      ctx.mna.stampRhs(k, -r * _iPrev);
    }
  }

  @override
  void stampAc(AcStampContext ctx) {
    final k = _k;
    ctx.mna.stampMatrix(n1, k, Complex.one);
    ctx.mna.stampMatrix(n2, k, -Complex.one);
    ctx.mna.stampMatrix(k, n1, Complex.one);
    ctx.mna.stampMatrix(k, n2, -Complex.one);
    ctx.mna.stampMatrix(k, k, Complex(0, -ctx.omega * inductance));
  }

  @override
  void acceptTimestep(Float64List solution, double time, double timeStep) {
    _iPrev = solution[_k];
    final v1 = n1 < 0 ? 0.0 : solution[n1];
    final v2 = n2 < 0 ? 0.0 : solution[n2];
    _vPrev = v1 - v2;
    _historyValid = true;
  }

  void setInitialState(double i) {
    _iPrev = i;
    _vPrev = 0.0;
    // Leave history "invalid" so the first transient step uses Backward Euler,
    // which needs only the initial current (not a prior voltage).
    _historyValid = false;
  }

  @override
  void reset() {
    _iPrev = 0.0;
    _vPrev = 0.0;
    _historyValid = false;
  }
}
