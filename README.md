# ngspice_dart

[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-brightgreen.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.12.1-0175C2.svg?logo=dart)](https://dart.dev)
[![Dart FFI](https://img.shields.io/badge/Dart_FFI-Native_C_Bindings-teal.svg?logo=c)](https://dart.dev/interop/c-interop)
[![Pub Version](https://img.shields.io/pub/v/ngspice_dart)](https://pub.dev/packages/ngspice_dart)
[![ngspice Website](https://img.shields.io/badge/ngspice-website-orange.svg)](https://ngspice.sourceforge.io/)
[![ngspice Repo](https://img.shields.io/badge/ngspice-repository-orange.svg)](https://sourceforge.net/p/ngspice/ngspice/)

Dart FFI bindings for the **ngspice** mixed-level/mixed-signal circuit simulator, allowing native execution of SPICE simulations directly in Flutter and Dart.

This plugin allows you to parse netlists, run simulations (transient, AC, DC, etc.), and retrieve vector data directly into Dart.

## Features

- **Initialize ngspice**: Load the simulator engine natively.
- **Execute SPICE Commands**: Run commands just like in the ngspice interactive console (e.g. `run`, `print all`).
- **Load Circuits**: Parse netlists directly from an array of strings in memory.
- **Data Retrieval**: Extract simulation vectors (real data) into Dart `List<double>` for plotting or analysis.

## Setup & Requirements

> **IMPORTANT:** Because `ngspice` is a massive C codebase relying on `autotools` rather than standard mobile build systems, compiling it from source across all mobile architectures natively is complex.
>
> You **must provide the pre-compiled ngspice shared library** (`libngspice.so`, `libngspice.dylib`, or `ngspice.dll`) for the target platforms and bundle them within your Flutter application.

### macOS Example

If you compile `libngspice.dylib` locally on your Mac, you can drop it into the `macos/` folder of this plugin and it will be bundled automatically via the podspec:

```ruby
s.vendored_libraries = 'libngspice.dylib'
```

## Usage

```dart
import 'package:ngspice_dart/ngspice_dart.dart';

void main() {
  final ngspice = Ngspice();

  // 1. Initialize the engine
  ngspice.init();

  // 2. Load a circuit
  ngspice.circuit([
    '* A simple RC circuit',
    'v1 1 0 dc 5',
    'r1 1 2 1k',
    'c1 2 0 1u',
    '.tran 0.1m 10m',
    '.end'
  ]);

  // 3. Run the simulation
  ngspice.command('run');

  // 4. Retrieve data (e.g., voltage at node 1)
  final vec = ngspice.getVector('v(1)');
  if (vec != null) {
    print('Voltage at node 1: \${vec.first} V');
  }
}
```

## Re-generating Bindings

If you need to update the FFI bindings to a newer version of ngspice's `sharedspice.h`:

1. Place the new `sharedspice.h` in the `src/ngspice/src/include/ngspice/` directory.
2. Run `dart run ffigen --config ffigen.yaml`.
