import '../numeric/complex.dart';
import 'device.dart';

/// Voltage-controlled voltage source (SPICE `E`):
/// `Exxx n+ n- nc+ nc- gain`, enforcing V(n+,n-) = gain * V(nc+,nc-).
/// Adds one branch-current unknown.
class Vcvs extends Device {
  final int nPlus;
  final int nMinus;
  final int ncPlus;
  final int ncMinus;
  final double gain;

  Vcvs(super.name, this.nPlus, this.nMinus, this.ncPlus, this.ncMinus,
      this.gain);

  @override
  int get branchCount => 1;

  int get _k => branchBase;

  @override
  void stamp(StampContext ctx) {
    final k = _k;
    ctx.mna.stampMatrix(nPlus, k, 1.0);
    ctx.mna.stampMatrix(nMinus, k, -1.0);
    // V(n+) - V(n-) - gain*(V(nc+) - V(nc-)) = 0
    ctx.mna.stampMatrix(k, nPlus, 1.0);
    ctx.mna.stampMatrix(k, nMinus, -1.0);
    ctx.mna.stampMatrix(k, ncPlus, -gain);
    ctx.mna.stampMatrix(k, ncMinus, gain);
  }

  @override
  void stampAc(AcStampContext ctx) {
    final k = _k;
    final g = Complex.real(gain);
    ctx.mna.stampMatrix(nPlus, k, Complex.one);
    ctx.mna.stampMatrix(nMinus, k, -Complex.one);
    ctx.mna.stampMatrix(k, nPlus, Complex.one);
    ctx.mna.stampMatrix(k, nMinus, -Complex.one);
    ctx.mna.stampMatrix(k, ncPlus, -g);
    ctx.mna.stampMatrix(k, ncMinus, g);
  }
}

/// Voltage-controlled current source (SPICE `G`):
/// `Gxxx n+ n- nc+ nc- gm`, injecting I(n+ -> n-) = gm * V(nc+,nc-).
/// No extra unknown is required.
class Vccs extends Device {
  final int nPlus;
  final int nMinus;
  final int ncPlus;
  final int ncMinus;
  final double gm;

  Vccs(super.name, this.nPlus, this.nMinus, this.ncPlus, this.ncMinus, this.gm);

  @override
  void stamp(StampContext ctx) {
    // Current leaving n+ (entering n-) equals gm*(V(nc+) - V(nc-)).
    ctx.mna.stampMatrix(nPlus, ncPlus, gm);
    ctx.mna.stampMatrix(nPlus, ncMinus, -gm);
    ctx.mna.stampMatrix(nMinus, ncPlus, -gm);
    ctx.mna.stampMatrix(nMinus, ncMinus, gm);
  }

  @override
  void stampAc(AcStampContext ctx) {
    final g = Complex.real(gm);
    ctx.mna.stampMatrix(nPlus, ncPlus, g);
    ctx.mna.stampMatrix(nPlus, ncMinus, -g);
    ctx.mna.stampMatrix(nMinus, ncPlus, -g);
    ctx.mna.stampMatrix(nMinus, ncMinus, g);
  }
}
