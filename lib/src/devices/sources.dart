import '../circuit/mna.dart';
import '../numeric/complex.dart';
import 'device.dart';
import 'waveform.dart';

/// Independent voltage source between [nPlus] and [nMinus]. Adds one branch
/// current unknown (current flowing nPlus -> nMinus through the source).
class VoltageSource extends Device {
  final int nPlus;
  final int nMinus;
  final SourceWaveform waveform;

  /// When set, overrides the DC value during a `.dc` sweep.
  double? dcSweepValue;

  /// Runtime DC value override set via the interactive `alter` command. Takes
  /// precedence over the parsed waveform DC for operating-point and DC analyses
  /// (but not over a transient stimulus during transient analysis). This lets
  /// callers re-solve with a changed source value without rebuilding the deck.
  double? dcOverride;

  VoltageSource(super.name, this.nPlus, this.nMinus, this.waveform);

  @override
  int get branchCount => 1;

  int get _k => branchBase;

  double _value(StampContext ctx) {
    if (ctx.mode == AnalysisMode.dc && dcSweepValue != null) {
      return dcSweepValue!;
    }
    final override = dcOverride;
    if (override != null &&
        !(ctx.mode == AnalysisMode.transient && waveform.transient != null)) {
      return override;
    }
    return waveform.valueAt(ctx.time, ctx.mode);
  }

  @override
  void stamp(StampContext ctx) {
    final k = _k;
    ctx.mna.stampMatrix(nPlus, k, 1.0);
    ctx.mna.stampMatrix(nMinus, k, -1.0);
    ctx.mna.stampMatrix(k, nPlus, 1.0);
    ctx.mna.stampMatrix(k, nMinus, -1.0);
    ctx.mna.stampRhs(k, _value(ctx));
  }

  @override
  void stampAc(AcStampContext ctx) {
    final k = _k;
    ctx.mna.stampMatrix(nPlus, k, Complex.one);
    ctx.mna.stampMatrix(nMinus, k, -Complex.one);
    ctx.mna.stampMatrix(k, nPlus, Complex.one);
    ctx.mna.stampMatrix(k, nMinus, -Complex.one);
    ctx.mna.stampRhs(
        k,
        Complex.polar(
            waveform.acMag, waveform.acPhase * 3.141592653589793 / 180.0));
  }

  /// Branch current of this source from an accepted solution.
  double currentFrom(List<double> solution) => solution[_k];
}

/// Independent current source. Positive current flows from [nPlus], through the
/// source, to [nMinus] (standard SPICE convention).
class CurrentSource extends Device {
  final int nPlus;
  final int nMinus;
  final SourceWaveform waveform;

  /// When set, overrides the DC value during a `.dc` sweep.
  double? dcSweepValue;

  /// Runtime DC value override set via the interactive `alter` command.
  double? dcOverride;

  CurrentSource(super.name, this.nPlus, this.nMinus, this.waveform);

  @override
  void stamp(StampContext ctx) {
    final i = (ctx.mode == AnalysisMode.dc && dcSweepValue != null)
        ? dcSweepValue!
        : (dcOverride != null &&
                !(ctx.mode == AnalysisMode.transient &&
                    waveform.transient != null))
            ? dcOverride!
            : waveform.valueAt(ctx.time, ctx.mode);
    // Current leaves nPlus and enters nMinus.
    ctx.mna.stampCurrentSource(nPlus, nMinus, i);
  }

  @override
  void stampAc(AcStampContext ctx) {
    final i = Complex.polar(
        waveform.acMag, waveform.acPhase * 3.141592653589793 / 180.0);
    ctx.mna.stampRhs(nPlus, -i);
    ctx.mna.stampRhs(nMinus, i);
  }
}
