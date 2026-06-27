## 0.2.0

- **Native Dart port.** Replaced the FFI binding to `libngspice` with a
  self-contained, pure-Dart simulation engine. No native library, no FFI, no
  platform build — runs anywhere Dart runs.
- Added a SPICE netlist parser (engineering suffixes, `+` continuations,
  comments, `.model D`, `.ic`, `.options`).
- Added Modified Nodal Analysis assembly with a dense LU solver (real) and a
  complex solver for AC.
- Added device models: resistor, capacitor, inductor, independent V/I sources
  (DC/AC/SIN/PULSE/PWL), and a Newton-Raphson diode with `pnjlim` limiting.
- Added analyses: `.op`, `.dc` sweep, `.tran` (Backward-Euler / Trapezoidal),
  and `.ac` (`dec`/`oct`/`lin`).
- Preserved the `Ngspice` facade for backwards compatibility; added
  `NgspiceEngine`, `SimResult`, and complex-vector retrieval.
- Removed the Flutter plugin scaffolding, vendored `libngspice` binaries, and
  generated FFI bindings.

## 0.1.0

- Initial open source release.
- Added Dart FFI bindings for ngspice.
- Added `Ngspice` API class with initialization, circuit loading, command execution and vector retrieval.
- Built from [ngspice repository](https://sourceforge.net/p/ngspice/ngspice/ci/master/tree/), branch `master`, commit `037b6578f87524cba74cd5ee5b2f9c1536f76ead`.
