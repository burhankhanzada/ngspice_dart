import 'dart:typed_data';

import 'complex.dart';

/// Thrown when a linear system cannot be solved (singular matrix).
class SingularMatrixException implements Exception {
  final String message;
  SingularMatrixException([this.message = 'Matrix is singular']);
  @override
  String toString() => 'SingularMatrixException: $message';
}

/// A dense square real matrix with an in-place RHS solver, used to assemble and
/// solve the Modified Nodal Analysis (MNA) system `A x = b`.
///
/// The matrix is stored row-major in a [Float64List]. For the circuit sizes a
/// typical SPICE deck produces (tens to low hundreds of unknowns) a dense LU
/// with partial pivoting is robust and fast enough; a sparse backend can be
/// dropped in behind the same interface later.
class RealMatrix {
  final int n;
  final Float64List _a;

  RealMatrix(this.n) : _a = Float64List(n * n);

  double get(int r, int c) => _a[r * n + c];
  void set(int r, int c, double v) => _a[r * n + c] = v;
  void add(int r, int c, double v) => _a[r * n + c] += v;

  void clear() => _a.fillRange(0, _a.length, 0);

  RealMatrix copy() {
    final m = RealMatrix(n);
    m._a.setAll(0, _a);
    return m;
  }

  /// Solves `A x = b`, returning x. [b] is not modified. Uses LU decomposition
  /// with partial pivoting on a working copy of A.
  Float64List solve(Float64List b) {
    assert(b.length == n);
    final a = Float64List.fromList(_a);
    final x = Float64List.fromList(b);
    final piv = Int32List(n);
    for (var i = 0; i < n; i++) {
      piv[i] = i;
    }

    for (var col = 0; col < n; col++) {
      // Partial pivot: find row with the largest magnitude in this column.
      var maxRow = col;
      var maxVal = a[col * n + col].abs();
      for (var r = col + 1; r < n; r++) {
        final v = a[r * n + col].abs();
        if (v > maxVal) {
          maxVal = v;
          maxRow = r;
        }
      }
      if (maxVal < 1e-300) {
        throw SingularMatrixException(
            'Zero pivot in column $col (no DC path / floating node?)');
      }
      if (maxRow != col) {
        _swapRows(a, col, maxRow);
        final t = x[col];
        x[col] = x[maxRow];
        x[maxRow] = t;
      }

      final pivot = a[col * n + col];
      for (var r = col + 1; r < n; r++) {
        final f = a[r * n + col] / pivot;
        if (f == 0) continue;
        a[r * n + col] = 0;
        for (var c = col + 1; c < n; c++) {
          a[r * n + c] -= f * a[col * n + c];
        }
        x[r] -= f * x[col];
      }
    }

    // Back substitution.
    for (var r = n - 1; r >= 0; r--) {
      var s = x[r];
      for (var c = r + 1; c < n; c++) {
        s -= a[r * n + c] * x[c];
      }
      x[r] = s / a[r * n + r];
    }
    return x;
  }

  void _swapRows(Float64List a, int r1, int r2) {
    for (var c = 0; c < n; c++) {
      final t = a[r1 * n + c];
      a[r1 * n + c] = a[r2 * n + c];
      a[r2 * n + c] = t;
    }
  }
}

/// A dense complex square matrix + solver, used for AC small-signal analysis.
class ComplexMatrix {
  final int n;
  final List<Complex> _a;

  ComplexMatrix(this.n) : _a = List<Complex>.filled(n * n, Complex.zero);

  Complex get(int r, int c) => _a[r * n + c];
  void set(int r, int c, Complex v) => _a[r * n + c] = v;
  void add(int r, int c, Complex v) => _a[r * n + c] = _a[r * n + c] + v;

  void clear() {
    for (var i = 0; i < _a.length; i++) {
      _a[i] = Complex.zero;
    }
  }

  /// Solves `A x = b` for complex x via Gaussian elimination with partial
  /// pivoting on magnitude.
  List<Complex> solve(List<Complex> b) {
    assert(b.length == n);
    final a = List<Complex>.of(_a);
    final x = List<Complex>.of(b);

    for (var col = 0; col < n; col++) {
      var maxRow = col;
      var maxVal = a[col * n + col].abs;
      for (var r = col + 1; r < n; r++) {
        final v = a[r * n + col].abs;
        if (v > maxVal) {
          maxVal = v;
          maxRow = r;
        }
      }
      if (maxVal < 1e-300) {
        throw SingularMatrixException('Zero pivot in column $col (AC)');
      }
      if (maxRow != col) {
        for (var c = 0; c < n; c++) {
          final t = a[col * n + c];
          a[col * n + c] = a[maxRow * n + c];
          a[maxRow * n + c] = t;
        }
        final t = x[col];
        x[col] = x[maxRow];
        x[maxRow] = t;
      }

      final pivot = a[col * n + col];
      for (var r = col + 1; r < n; r++) {
        final f = a[r * n + col] / pivot;
        if (f == Complex.zero) continue;
        a[r * n + col] = Complex.zero;
        for (var c = col + 1; c < n; c++) {
          a[r * n + c] = a[r * n + c] - f * a[col * n + c];
        }
        x[r] = x[r] - f * x[col];
      }
    }

    for (var r = n - 1; r >= 0; r--) {
      var s = x[r];
      for (var c = r + 1; c < n; c++) {
        s = s - a[r * n + c] * x[c];
      }
      x[r] = s / a[r * n + r];
    }
    return x;
  }
}
