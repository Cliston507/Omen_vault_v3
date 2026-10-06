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
    pkgs.sqlcipher
    pkgs.openssl
    pkgs.libsecret
  ];

  env = {
    CMAKE_MAKE_PROGRAM = "${pkgs.ninja}/bin/ninja";
    CMAKE_CXX_COMPILER = "${pkgs.clang}/bin/clang++";
    PKG_CONFIG_PATH = "${pkgs.sqlcipher}/lib/pkgconfig:${pkgs.gtk3}/lib/pkgconfig:${pkgs.glib}/lib/pkgconfig:${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.libsecret}/lib/pkgconfig";
  };

   idx.previews = {
     enable = true;
     previews = {
       web = {
         command = ["flutter" "run" "--machine" "-d" "web-server" "--web-port" "$PORT" "--web-hostname" "0.0.0.0"];
         manager = "flutter";
       };
     };
   };
}