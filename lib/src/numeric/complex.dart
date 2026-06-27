import 'dart:math' as math;

/// A minimal immutable complex number used for AC (small-signal) analysis.
class Complex {
  final double re;
  final double im;

  const Complex(this.re, this.im);

  static const Complex zero = Complex(0, 0);
  static const Complex one = Complex(1, 0);

  factory Complex.real(double r) => Complex(r, 0);

  /// Construct from magnitude [r] and angle [theta] (radians).
  factory Complex.polar(double r, double theta) =>
      Complex(r * math.cos(theta), r * math.sin(theta));

  Complex operator +(Complex o) => Complex(re + o.re, im + o.im);
  Complex operator -(Complex o) => Complex(re - o.re, im - o.im);
  Complex operator *(Complex o) =>
      Complex(re * o.re - im * o.im, re * o.im + im * o.re);

  Complex operator /(Complex o) {
    final d = o.re * o.re + o.im * o.im;
    return Complex(
      (re * o.re + im * o.im) / d,
      (im * o.re - re * o.im) / d,
    );
  }

  Complex operator -() => Complex(-re, -im);

  Complex scale(double s) => Complex(re * s, im * s);

  /// Magnitude (modulus).
  double get abs => math.sqrt(re * re + im * im);

  /// Phase angle in radians.
  double get arg => math.atan2(im, re);

  /// Phase angle in degrees.
  double get argDegrees => arg * 180.0 / math.pi;

  /// Magnitude expressed in decibels (20*log10).
  double get db => 20.0 * (math.log(abs) / math.ln10);

  @override
  bool operator ==(Object other) =>
      other is Complex && other.re == re && other.im == im;

  @override
  int get hashCode => Object.hash(re, im);

  @override
  String toString() => im >= 0 ? '$re+${im}i' : '$re${im}i';
}
