// A small tour of the pure-Dart ngspice engine: operating point, transient and
// AC analysis, all running natively with no FFI / native library.
//
// Run with:  dart run example/ngspice_example.dart
import 'package:ngspice_dart/ngspice_dart.dart';

void main() {
  _operatingPoint();
  _transientRcStep();
  _acLowPass();
}

void _operatingPoint() {
  print('== DC operating point: resistive divider ==');
  final ng = Ngspice();
  ng.circuit([
    'Divider',
    'V1 in 0 dc 10',
    'R1 in out 1k',
    'R2 out 0 3k',
    '.op',
    '.end',
  ]);
  ng.command('run');
  print('  V(out) = ${ng.getVector('v(out)')!.first} V  (expected 7.5)\n');
}

void _transientRcStep() {
  print('== Transient: RC charging from 0 V (UIC) ==');
  final ng = Ngspice();
  ng.circuit([
    'RC step',
    'V1 1 0 dc 5',
    'R1 1 2 1k',
    'C1 2 0 1u ic=0',
    '.tran 0.1m 5m uic',
    '.end',
  ]);
  ng.command('run');

  final result = ng.engine.currentResult!;
  final time = result.sweep;
  final vc = result.realVector('v(2)')!;
  print('  time(ms)   V(2)');
  for (var i = 0; i < time.length; i += 10) {
    print('  ${(time[i] * 1e3).toStringAsFixed(2).padLeft(6)}    '
        '${vc[i].toStringAsFixed(4)}');
  }
  print('');
}

void _acLowPass() {
  print('== AC: RC low-pass magnitude response ==');
  final ng = Ngspice();
  ng.circuit([
    'RC low-pass',
    'V1 1 0 dc 0 ac 1',
    'R1 1 2 1k',
    'C1 2 0 159.155n', // fc ~ 1 kHz
    '.ac dec 10 10 100k',
    '.end',
  ]);
  ng.command('run');

  final result = ng.engine.currentResult!;
  final freqs = result.sweep;
  final vout = result.complexVector('v(2)')!;
  print('  freq(Hz)      |V(2)|      phase(deg)');
  for (var i = 0; i < freqs.length; i += 5) {
    print('  ${freqs[i].toStringAsFixed(1).padLeft(9)}   '
        '${vout[i].abs.toStringAsFixed(4)}     '
        '${vout[i].argDegrees.toStringAsFixed(1)}');
  }
}
