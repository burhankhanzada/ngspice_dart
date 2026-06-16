# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(ngspice_dart_library VERSION 0.0.1 LANGUAGES C)

add_library(ngspice_dart SHARED
  "ngspice_dart.c"
)

set_target_properties(ngspice_dart PROPERTIES
  PUBLIC_HEADER ngspice_dart.h
  OUTPUT_NAME "ngspice_dart"
)

target_compile_definitions(ngspice_dart PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(ngspice_dart PRIVATE "-Wl,-z,max-page-size=16384")
endif()
