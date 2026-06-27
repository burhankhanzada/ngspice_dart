import 'package:test/test.dart';
import 'package:ngspice_dart/ngspice_dart.dart';

void main() {
  group('Ngspice Initialization and Execution', () {
    late Ngspice ngspice;

    setUpAll(() {
      ngspice = Ngspice();
    });

    test('should initialize successfully', () {
      final initResult = ngspice.init();
      expect(initResult, equals(0),
          reason: 'Initialization should return 0 (success)');
    });

    test('should execute a simple command', () {
      final cmdResult = ngspice.command('print all');
      expect(cmdResult, equals(0),
          reason: 'Command execution should return 0 (success)');
    });

    test('should load a simple RC circuit', () {
      final circResult = ngspice.circuit([
        '* A simple RC circuit',
        'v1 1 0 dc 5',
        'r1 1 2 1k',
        'c1 2 0 1u',
        '.tran 0.1m 10m',
        '.end'
      ]);
      expect(circResult, equals(0),
          reason: 'Circuit loading should return 0 (success)');
    });

    test('should run the simulation', () {
      final runResult = ngspice.command('run');
      expect(runResult, equals(0),
          reason: 'Simulation run should return 0 (success)');
    });

    test('should get vector data', () {
      final vec = ngspice.getVector('v(1)');
      expect(vec, isNotNull);
      expect(vec!.isNotEmpty, isTrue);
      // Since it's a step simulation or tran, we should have values.
      expect(vec.first, closeTo(5.0, 1e-4));
    });
  });
}
