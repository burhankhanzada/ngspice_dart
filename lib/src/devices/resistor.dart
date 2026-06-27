import '../numeric/complex.dart';
import 'device.dart';

/// Linear resistor between nodes [n1] and [n2] with resistance [resistance].
class Resistor extends Device {
  final int n1;
  final int n2;
  final double resistance;

  Resistor(super.name, this.n1, this.n2, this.resistance);

  double get conductance => 1.0 / resistance;

  @override
  void stamp(StampContext ctx) {
    ctx.mna.stampConductance(n1, n2, conductance);
  }

  @override
  void stampAc(AcStampContext ctx) {
    ctx.mna.stampAdmittance(n1, n2, Complex.real(conductance));
  }
}
