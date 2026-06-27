import 'dart:math' as math;

import '../circuit/mna.dart';

/// A time-domain stimulus function for an independent source.
abstract class TransientFunction {
  double eval(double t);
}

/// SIN(vo va freq td theta phase)
class SinFunction extends TransientFunction {
  final double vo, va, freq, td, theta, phaseDeg;
  SinFunction(this.vo, this.va, this.freq,
      {this.td = 0, this.theta = 0, this.phaseDeg = 0});

  @override
  double eval(double t) {
    if (t < td) {
      return vo + va * math.sin(phaseDeg * math.pi / 180.0);
    }
    final dt = t - td;
    final damp = theta != 0 ? math.exp(-dt * theta) : 1.0;
    return vo +
        va *
            damp *
            math.sin(2 * math.pi * freq * dt + phaseDeg * math.pi / 180.0);
  }
}

/// PULSE(v1 v2 td tr tf pw per)
class PulseFunction extends TransientFunction {
  final double v1, v2, td, tr, tf, pw, per;
  PulseFunction(this.v1, this.v2,
      {this.td = 0, this.tr = 0, this.tf = 0, this.pw = 0, this.per = 0});

  @override
  double eval(double t) {
    if (t < td) return v1;
    var tau = t - td;
    if (per > 0 && tau >= per) {
      tau = tau % per;
    }
    if (tr > 0 && tau < tr) {
      return v1 + (v2 - v1) * (tau / tr);
    }
    tau -= tr;
    if (tau < pw) return v2;
    tau -= pw;
    if (tf > 0 && tau < tf) {
      return v2 + (v1 - v2) * (tau / tf);
    }
    return v1;
  }
}

/// PWL(t0 v0 t1 v1 ...) piecewise-linear stimulus.
class PwlFunction extends TransientFunction {
  final List<double> times;
  final List<double> values;
  PwlFunction(this.times, this.values);

  @override
  double eval(double t) {
    if (times.isEmpty) return 0;
    if (t <= times.first) return values.first;
    if (t >= times.last) return values.last;
    for (var i = 0; i < times.length - 1; i++) {
      if (t >= times[i] && t <= times[i + 1]) {
        final frac = (t - times[i]) / (times[i + 1] - times[i]);
        return values[i] + (values[i + 1] - values[i]) * frac;
      }
    }
    return values.last;
  }
}

/// Complete description of an independent source's value across analyses.
class SourceWaveform {
  /// DC operating-point / quiescent value.
  final double dc;

  /// AC magnitude and phase (degrees) for small-signal analysis.
  final double acMag;
  final double acPhase;

  /// Optional time-domain stimulus used during transient analysis.
  final TransientFunction? transient;

  SourceWaveform({
    this.dc = 0,
    this.acMag = 0,
    this.acPhase = 0,
    this.transient,
  });

  /// Returns the source value to stamp for the given analysis at time [t].
  double valueAt(double t, AnalysisMode mode) {
    if (mode == AnalysisMode.transient && transient != null) {
      return transient!.eval(t);
    }
    return dc;
  }
}
