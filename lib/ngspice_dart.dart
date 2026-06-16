import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'ngspice_dart_bindings_generated.dart';

const String _libName = 'ngspice';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('lib$_libName.dylib');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final NgspiceDartBindings _bindings = NgspiceDartBindings(_dylib);

class Ngspice {
  static final Ngspice _instance = Ngspice._internal();

  factory Ngspice() {
    return _instance;
  }

  Ngspice._internal();

  /// Initialize ngspice
  int init() {
    return _bindings.ngSpice_Init(
      nullptr, // printfcn
      nullptr, // statfcn
      nullptr, // ngexit
      nullptr, // sdata
      nullptr, // sinitdata
      nullptr, // bgtrun
      nullptr, // userData
    );
  }

  /// Execute a command
  int command(String cmd) {
    final cmdPtr = cmd.toNativeUtf8();
    final result = _bindings.ngSpice_Command(cmdPtr.cast<Char>());
    malloc.free(cmdPtr);
    return result;
  }

  /// Load a circuit from an array of strings
  int circuit(List<String> circArray) {
    final pointers = malloc<Pointer<Char>>(circArray.length + 1);
    for (int i = 0; i < circArray.length; i++) {
      pointers[i] = circArray[i].toNativeUtf8().cast<Char>();
    }
    pointers[circArray.length] = nullptr;
    
    final result = _bindings.ngSpice_Circ(pointers);
    
    for (int i = 0; i < circArray.length; i++) {
      malloc.free(pointers[i]);
    }
    malloc.free(pointers);
    
    return result;
  }

  /// Get real data vector by name
  List<double>? getVector(String vecName) {
    final namePtr = vecName.toNativeUtf8();
    final infoPtr = _bindings.ngGet_Vec_Info(namePtr.cast<Char>());
    malloc.free(namePtr);

    if (infoPtr == nullptr) {
      return null;
    }

    final info = infoPtr.ref;
    final length = info.v_length;
    if (length <= 0) return null;

    if (info.v_realdata != nullptr) {
      final data = <double>[];
      for (int i = 0; i < length; i++) {
        data.add(info.v_realdata[i]);
      }
      return data;
    }

    return null;
  }
}
