import 'dart:typed_data';

import '../numeric/complex.dart';
import '../numeric/linear_solver.dart';

/// Which analysis is currently driving the stamp.
enum AnalysisMode { operatingPoint, dc, transient, ac }

/// Numerical integration method for reactive (C/L) companion models.
enum IntegrationMethod { backwardEuler, trapezoidal }

/// The real-valued MNA system being assembled for an OP/DC/transient solve.
///
/// Stamps that reference the ground node (index < 0) are silently dropped,
/// which is exactly the row/column elimination that grounding the reference
/// node performs.
class Mna {
  final int size;
  final RealMatrix matrix;
  final Float64List rhs;

  Mna(this.size)
      : matrix = RealMatrix(size),
        rhs = Float64List(size);

  void reset() {
    matrix.clear();
    rhs.fillRange(0, size, 0);
  }

  /// Adds [g] to the conductance matrix at (i, j), skipping ground.
  void stampMatrix(int i, int j, double g) {
    if (i >= 0 && j >= 0) matrix.add(i, j, g);
  }

  /// Adds [v] to the right-hand side at row i, skipping ground.
  void stampRhs(int i, double v) {
    if (i >= 0) rhs[i] += v;
  }

  /// Convenience: stamp a conductance [g] between nodes [a] and [b].
  void stampConductance(int a, int b, double g) {
    stampMatrix(a, a, g);
    stampMatrix(b, b, g);
    stampMatrix(a, b, -g);
    stampMatrix(b, a, -g);
  }

  /// Convenience: inject current [i] from node [a] into node [b]
  /// (i.e. a current source flowing a -> b).
  void stampCurrentSource(int a, int b, double i) {
    stampRhs(a, -i);
    stampRhs(b, i);
  }

  Float64List solve() => matrix.solve(rhs);
}

/// The complex-valued MNA system used by AC analysis. Same stamping rules.
class AcMna {
  final int size;
  final ComplexMatrix matrix;
  final List<Complex> rhs;

  AcMna(this.size)
      : matrix = ComplexMatrix(size),
        rhs = List<Complex>.filled(size, Complex.zero);

  void reset() {
    matrix.clear();
    for (var i = 0; i < size; i++) {
      rhs[i] = Complex.zero;
    }
  }

  void stampMatrix(int i, int j, Complex y) {
    if (i >= 0 && j >= 0) matrix.add(i, j, y);
  }

  void stampRhs(int i, Complex v) {
    if (i >= 0) rhs[i] = rhs[i] + v;
  }

  void stampAdmittance(int a, int b, Complex y) {
    stampMatrix(a, a, y);
    stampMatrix(b, b, y);
    stampMatrix(a, b, -y);
    stampMatrix(b, a, -y);
  }

  List<Complex> solve() => matrix.solve(rhs);
}
