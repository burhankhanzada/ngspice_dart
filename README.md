# ngspice_dart

[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.5-0175C2.svg?logo=dart)](https://dart.dev)
[![Pub Version](https://img.shields.io/pub/v/ngspice_dart)](https://pub.dev/packages/ngspice_dart)

A **native Dart port** of the [ngspice](https://ngspice.sourceforge.io/) SPICE
circuit simulator. Netlist parsing, Modified Nodal Analysis (MNA) assembly, the
Newton–Raphson nonlinear solver and the OP / DC / transient / AC analyses all
run in **pure Dart** — there is no FFI, no native library to compile, and no
platform-specific build. It runs anywhere Dart runs: Flutter (all platforms),
server, CLI, and the web.

> This package was previously a thin FFI binding to the C `libngspice`. It has
> been reimplemented as a self-contained Dart simulation engine. The original
> `Ngspice` facade (`init` / `command` / `circuit` / `getVector`) is preserved
> for backwards compatibility.

## What's implemented

| Area                 | Support                                                                                                                           |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Elements**         | Resistor `R`, Capacitor `C`, Inductor `L`, independent V/I sources, Diode `D`, VCVS `E`, VCCS `G`                                 |
| **Source waveforms** | `DC`, `AC mag/phase`, `SIN`, `PULSE`, `PWL`                                                                                       |
| **Analyses**         | `.op`, `.dc` sweep, `.tran` (Backward-Euler / Trapezoidal), `.ac` (`dec`/`oct`/`lin`)                                             |
| **Solver**           | Dense LU with partial pivoting; Newton–Raphson with `pnjlim` junction limiting and `gmin`                                         |
| **Parsing**          | SPICE engineering suffixes (`k`, `meg`, `u`, `n`, `p`, …), `+` continuations, `*`/`;`/`$` comments, `.model D`, `.ic`, `.options` |

This is a meaningful, growing subset of ngspice — not yet the full device library
(BJTs, MOSFETs, transmission lines, etc.). Contributions of additional device
models stamp cleanly onto the existing `Device` interface.

## Usage

```dart
import 'package:ngspice_dart/ngspice_dart.dart';

void main() {
  final ngspice = Ngspice();

  // Load a circuit from netlist lines.
  ngspice.circuit([
    'RC low-pass',
    'V1 1 0 dc 0 ac 1',
    'R1 1 2 1k',
    'C1 2 0 159.155n',
    '.ac dec 10 10 100k',
    '.end',
  ]);

  // Run the declared analyses.
  ngspice.command('run');

  // Retrieve results.
  final mag = ngspice.getVector('v(2)');          // magnitude (AC)
  final cplx = ngspice.getComplexVector('v(2)');  // full complex vector
  print('Gain at first point: ${mag!.first}');
}
```

### Native engine API

For multiple result plots, the parsed circuit, and complex AC data, use
[`NgspiceEngine`] directly:

```dart
final engine = NgspiceEngine();
engine.loadCircuit(netlistLines);
engine.run();

final result = engine.currentResult!;   // SimResult: sweep + named vectors
final time = result.sweep;               // independent variable
final vout = result.realVector('v(out)');
```

See [`example/ngspice_example.dart`](example/ngspice_example.dart) for a tour of
OP, transient and AC analysis.

## Running

```sh
dart pub get
dart test
dart run example/ngspice_example.dart
```
