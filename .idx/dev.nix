{ pkgs, ... }: {
  channel = "stable-23.11";

  packages = [
    pkgs.flutter
    pkgs.dart
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.clang
    pkgs.gtk3
    pkgs.glib
    pkgs.gcc
    pkgs.sqlite
  ];

  env = {
    CMAKE_MAKE_PROGRAM = "${pkgs.ninja}/bin/ninja";
    CMAKE_CXX_COMPILER = "${pkgs.clang}/bin/clang++";
  };  }