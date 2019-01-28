#!/boot/bin/sh

# !!! IF YOU CHANGE THIS FILE !!! ... please ensure it's in sync with
# garnet/bin/fidl_compatibility_test/run_fidl_compatibility_test_garnet.sh. (The
# Garnet file should be similar to this file, but omit the Dart server.)

export FIDL_COMPATIBILITY_TEST_SERVERS=fuchsia-pkg://fuchsia.con/fidl_compatibility_test_server_cpp#meta/fidl_compatibility_test_server_cpp.cmx,fuchsia-pkg://fuchsia.con/fidl_compatibility_test_server_dart#meta/fidl_compatibility_test_server_dart.cmx,fuchsia-pkg://fuchsia.con/fidl_compatibility_test_server_go#meta/fidl_compatibility_test_server_go.cmx,fuchsia-pkg://fuchsia.con/fidl_compatibility_test_server_rust#meta/fidl_compatibility_test_server_rust.cmx
/pkgfs/packages/fidl_compatibility_test_bin/0/bin/app
