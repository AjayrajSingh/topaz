# GN Build Arguments

## All builds

### fvm_slice_size
The size of the FVM partition images "slice size". The FVM slice size is a
minimum size of a particular chunk of a partition that is stored within
FVM. A very small slice size may lead to decreased throughput. A very large
slice size may lead to wasted space. The selected default size of 8mb is
selected for conservation of space, rather than performance.

**Current value (from the default):** `"8388608"`

From [//build/images/BUILD.gn:581](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#581)

### select_variant_canonical
*This should never be set as a build argument.*
It exists only to be set in `toolchain_args`.
See [//build/toolchain/clang_toolchain.gni](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/toolchain/clang_toolchain.gni) for details.

**Current value (from the default):** `[]`

From [//build/config/BUILDCONFIG.gn:618](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#618)

### toolchain_manifests
Manifest files describing target libraries from toolchains.
Can be either // source paths or absolute system paths.

**Current value (from the default):** `["/b/s/w/ir/kitchen-workdir/buildtools/linux-x64/clang/lib/aarch64-fuchsia.manifest"]`

From [//build/images/manifest.gni:11](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/manifest.gni#11)

### update_kernels
List of kernel images to include in the update (OTA) package.
If no list is provided, all built kernels are included. The names in the
list are strings that must match the filename to be included in the update
package.

**Current value (from the default):** `[]`

From [//build/images/BUILD.gn:367](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#367)

### bootfs_extra
List of extra manifest entries for files to add to the BOOTFS.
Each entry can be a "TARGET=SOURCE" string, or it can be a scope
with `sources` and `outputs` in the style of a copy() target:
`outputs[0]` is used as `TARGET` (see `gn help source_expansion`).

**Current value (from the default):** `[]`

From [//build/images/BUILD.gn:361](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#361)

### flutter_aot
Enable ahead-of-time compilation on platforms where AOT is optional.

**Current value (from the default):** `false`

From //third_party/flutter/common/config.gni:15

### flutter_space_dart
Whether experimental space dart mode is enabled for Flutter applications.

**Current value (from the default):** `false`

From [//topaz/runtime/dart/dart_component.gni:44](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/dart/dart_component.gni#44)

### select_variant_shortcuts
List of short names for commonly-used variant selectors.  Normally this
is not set as a build argument, but it serves to document the available
set of short-cut names for variant selectors.  Each element of this list
is a scope where `.name` is the short name and `.select_variant` is a
a list that can be spliced into [`select_variant`](#select_variant).

**Current value (from the default):**
```
[{
  name = "host_asan"
  select_variant = [{
  dir = ["//third_party/yasm", "//third_party/vboot_reference", "//garnet/tools/vboot_reference"]
  host = true
  variant = "asan_no_detect_leaks"
}, {
  host = true
  variant = "asan"
}]
}, {
  name = "asan"
  select_variant = [{
  target_type = ["driver_module"]
  variant = false
}, {
  host = false
  variant = "asan"
}]
}]
```

From [//build/config/BUILDCONFIG.gn:439](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#439)

### skia_enable_pdf

**Current value for `target_cpu = "arm64"`:** `false`

From //.gn:28

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:50

**Current value for `target_cpu = "x64"`:** `false`

From //.gn:28

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:50

### scenic_vulkan_swapchain

**Current value (from the default):** `1`

From [//garnet/lib/ui/gfx/BUILD.gn:12](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/ui/gfx/BUILD.gn#12)

### skia_enable_nvpr

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:43

### amber_keys_dir
Directory containing signing keys used by pm publish.

**Current value (from the default):** `"//garnet/go/src/amber/keys"`

From [//garnet/go/src/pm/pm.gni:14](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/go/src/pm/pm.gni#14)

### dart_debug
Instead of using is_debug, we introduce a different flag for specifying a
Debug build of Dart so that clients can still use a Release build of Dart
while themselves doing a Debug build.

**Current value (from the default):** `false`

From //third_party/dart/runtime/runtime_args.gni:9

### dart_zlib_path
The BUILD.gn file that we pull from chromium as part of zlib has a
dependence on //base, which we don't pull in. In a standalone build of the
VM, we set this to //runtime/bin/zlib where we have a BUILD.gn file without
a dependence on //base.

**Current value (from the default):** `"//third_party/zlib"`

From //third_party/dart/runtime/runtime_args.gni:49

### cloudkms_key_dir

**Current value (from the default):** `"projects/fuchsia-infra/locations/global/keyRings/test-secrets/cryptoKeys"`

From [//build/testing/secret_spec.gni:8](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/testing/secret_spec.gni#8)

### skia_use_wuffs

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:35

### dart_debug_optimization_level
The optimization level to use for debug builds. Defaults to 0 for builds with
code coverage enabled.

**Current value (from the default):** `"2"`

From //third_party/dart/runtime/runtime_args.gni:36

### synthesize_packages
List of extra packages to synthesize on the fly.  This is only for
things that do not appear normally in the source tree.  Synthesized
packages can contain build artifacts only if they already exist in some
part of the build.  They can contain arbitrary verbatim files.
Synthesized packages can't express dependencies on other packages.

Each element of this list is a scope that is very much like the body of
a package() template invocation (see [//build/package.gni](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/package.gni)).  That scope
must set `name` to the string naming the package, as would be the name
in the package() target written in a GN file.  This must be unique
among all package names.

**Current value (from the default):** `[]`

From [//build/gn/packages.gni:43](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/gn/packages.gni#43)

### dart_default_app
Controls whether dart_app() targets generate JIT or AOT Dart snapshots.
This defaults to JIT, use `fx set <ARCH> --args
'dart_default_app="dart_aot_app"' to switch to AOT.

**Current value (from the default):** `"dart_jit_app"`

From [//topaz/runtime/dart/dart_component.gni:20](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/dart/dart_component.gni#20)

### scenic_use_views2
Temporary flag, switches Flutter to using Scenic's new View API.

**Current value (from the default):** `false`

From [//garnet/bin/ui/scenic/config.gni:7](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/ui/scenic/config.gni#7)

### shell_skia_version

**Current value (from the default):** `""`

From //third_party/flutter/shell/version/version.gni:8

### extra_manifest_args
Extra args to globally apply to the manifest generation script.

**Current value (from the default):** `[]`

From [//build/images/manifest.gni:47](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/manifest.gni#47)

### ledger_sync_credentials_file

**Current value (from the default):** `""`

From [//peridot/bin/ledger/testing/sync_params.gni:6](https://fuchsia.googlesource.com/peridot/+/1edc9ea7dae206e90b36ce8d9e36633298c8fe87/bin/ledger/testing/sync_params.gni#6)

### rust_lto
Sets the default LTO type for rustc bulids.

**Current value (from the default):** `"unset"`

From [//build/rust/config.gni:20](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/rust/config.gni#20)

### skia_use_dng_sdk

**Current value for `target_cpu = "arm64"`:** `false`

From //.gn:29

**Overridden from the default:** `false`

From //third_party/skia/BUILD.gn:70

**Current value for `target_cpu = "x64"`:** `false`

From //.gn:29

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:70

### zircon_use_asan
Set this if [`zircon_build_dir`](#zircon_build_dir) was built with
`USE_ASAN=true`, e.g. `[//scripts/build-zircon.sh](https://fuchsia.googlesource.com/scripts/+/b507cf8f1ac2ca0de0f9c552ca5589da12b96c8b/build-zircon.sh) -A`.  This mainly
affects the defaults for [`zircon_build_dir`](#zircon_build_dir) and
[`zircon_build_abi_dir`](#zircon_build_abi_dir).  It also gets noticed
by [//scripts/fx](https://fuchsia.googlesource.com/scripts/+/b507cf8f1ac2ca0de0f9c552ca5589da12b96c8b/fx) commands that rebuild Zircon so that they use `-A`
again next time.

**Current value (from the default):** `false`

From [//build/config/fuchsia/zircon.gni:40](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/fuchsia/zircon.gni#40)

### clang_prefix

**Current value (from the default):** `"../buildtools/linux-x64/clang/bin"`

From [//build/config/clang/clang.gni:9](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/clang/clang.gni#9)

### dart_force_product
Forces all Dart and Flutter apps to build in a specific configuration that
we use to build products.

**Current value (from the default):** `false`

From [//topaz/runtime/dart/config.gni:10](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/dart/config.gni#10)

### dart_lib_export_symbols
Whether libdart should export the symbols of the Dart API.

**Current value (from the default):** `true`

From //third_party/dart/runtime/runtime_args.gni:93

### devmgr_config
List of arguments to add to /boot/config/devmgr.
These come after synthesized arguments to configure blobfs and pkgfs,
and the one generated for [`enable_crashpad`](#enable_crashpad).

**Current value (from the default):** `[]`

From [//build/images/BUILD.gn:344](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#344)

### extra_authorized_keys_file
Additional SSH authorized_keys file to include in the build.
For example:
  extra_authorized_keys_file=\"$HOME/.ssh/id_rsa.pub\"

**Current value (from the default):** `""`

From [//third_party/openssh-portable/fuchsia/developer-keys/BUILD.gn:11](https://fuchsia.googlesource.com/third_party/openssh-portable/+/06e7ff1f5cc2f48f85255ea20127746cd6fce423/fuchsia/developer-keys/BUILD.gn#11)

### thinlto_jobs
Number of parallel ThinLTO jobs.

**Current value (from the default):** `8`

From [//build/config/lto/config.gni:13](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/lto/config.gni#13)

### always_zedboot
Build boot images that prefer Zedboot over local boot (only for EFI).

**Current value (from the default):** `false`

From [//build/images/BUILD.gn:584](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#584)

### build_libvulkan
This is a list of targets that will be built as vulkan ICDS. If more than one
target is given then use_vulkan_loader_for_tests must be set to true, as
otherwise tests won't know which libvulkan to use.

**Current value (from the default):** `[]`

From [//garnet/lib/magma/gnbuild/magma.gni:38](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#38)

### dart_platform_bytecode
Whether the VM's platform dill file contains bytecode.

**Current value (from the default):** `false`

From //third_party/dart/runtime/runtime_args.gni:86

### extra_variants
Additional variant toolchain configs to support.
This is just added to [`known_variants`](#known_variants).

**Current value (from the default):** `[]`

From [//build/config/BUILDCONFIG.gn:393](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#393)

### fuchsia_packages
List of packages (a GN list of strings).
This list of packages is added to the set of "available" packages, see
`products` for more information.

**Current value for `target_cpu = "arm64"`:** `["topaz/packages/buildbot"]`

From //root_build_dir/args.gn:2

**Overridden from the default:** `[]`

From [//build/gn/packages.gni:30](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/gn/packages.gni#30)

**Current value for `target_cpu = "x64"`:** `["topaz/packages/buildbot"]`

From //root_build_dir/args.gn:2

**Overridden from the default:** `[]`

From [//build/gn/packages.gni:30](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/gn/packages.gni#30)

### skia_enable_effects

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:45

### skia_use_libjpeg_turbo

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:29

### skia_use_zlib

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:36

### amber_repository_dir
Directory containing files named by their merkleroot content IDs in
ASCII hex.  The [//build/image](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/image):pm_publish_blobs target populates
this with copies of build products, but never removes old files.

**Current value (from the default):** `"//root_build_dir/amber-files"`

From [//garnet/go/src/pm/pm.gni:11](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/go/src/pm/pm.gni#11)

### data_image_size
The size of the minfs data partition image to create. Normally this image
is added to FVM, and can therefore expand as needed. It must be at least
10mb (the default) in order to be succesfully initialized.

**Current value (from the default):** `"10m"`

From [//build/images/BUILD.gn:568](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#568)

### enable_value_subsystem

**Current value (from the default):** `false`

From [//garnet/bin/ui/scenic/BUILD.gn:11](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/ui/scenic/BUILD.gn#11)

### thinlto_cache_dir
ThinLTO cache directory path.

**Current value (from the default):** `"arm64-shared/thinlto-cache"`

From [//build/config/lto/config.gni:16](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/lto/config.gni#16)

### zedboot_cmdline_args
List of kernel command line arguments to bake into the Zedboot image.
See [//zircon/docs/kernel_cmdline.md](https://fuchsia.googlesource.com/zircon/+/cb56569a8270931be156ba1a82ddf603cd8707c7/docs/kernel_cmdline.md) and
[`zedboot_devmgr_config`](#zedboot_devmgr_config).

**Current value (from the default):** `[]`

From [//build/images/zedboot/BUILD.gn:15](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/zedboot/BUILD.gn#15)

### zircon_build_dir
Zircon build directory for `target_cpu`, containing `.manifest` and
`.zbi` files for Zircon's BOOTFS and kernel.  This provides the kernel
and Zircon components used in the boot image.  It also provides the
Zircon shared libraries used at runtime in Fuchsia packages.

If left `""` (the default), then this is computed from
[`zircon_build_abi_dir`](#zircon_build_abi_dir) and
[`zircon_use_asan`](#zircon_use_asan).

**Current value (from the default):** `""`

From [//build/config/fuchsia/zircon.gni:24](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/fuchsia/zircon.gni#24)

### zircon_system_groups
Groups to include from the Zircon /boot manifest into /system
(instead of into /boot like Zircon's own bootdata.bin does).
Should not include any groups that are also in zircon_boot_groups,
which see.  If zircon_boot_groups is "all" then this should be "".
**TODO(mcgrathr)**: _Could default to "" for `!is_debug`, or "production
build".  Note including `"test"` here places all of Zircon's tests into
`/system/test`, which means that Fuchsia bots run those tests too._

**Current value (from the default):** `"misc,test"`

From [//build/images/BUILD.gn:36](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#36)

### dart_snapshot_kind

**Current value (from the default):** `"kernel"`

From //third_party/dart/utils/application_snapshot.gni:14

### skia_enable_skpicture

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:52

### use_prebuilt_dart_sdk
Whether to use the prebuilt Dart SDK for everything.
When setting this to false, the preubilt Dart SDK will not be used in
situations where the version of the SDK matters, but may still be used as an
optimization where the version does not matter.

**Current value (from the default):** `true`

From [//build/dart/dart.gni:15](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/dart/dart.gni#15)

### skia_enable_effect_deserialization

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:47

### dart_runtime_mode
Set the runtime mode. This affects how the runtime is built and what
features it has. Valid values are:
'develop' (the default) - VM is built to run as a JIT with all development
features enabled.
'profile' - The VM is built to run with AOT compiled code with only the
CPU profiling features enabled.
'release' - The VM is built to run with AOT compiled code with no developer
features enabled.

These settings are only used for Flutter, at the moment. A standalone build
of the Dart VM should leave this set to "develop", and should set
'is_debug', 'is_release', or 'is_product'.

TODO(rmacnak): dart_runtime_mode no longer selects whether libdart is build
for JIT or AOT, since libdart waw split into libdart_jit and
libdart_precompiled_runtime. We should remove this flag and just set
dart_debug/dart_product.

**Current value (from the default):** `"develop"`

From //third_party/dart/runtime/runtime_args.gni:28

### scenic_enable_vulkan_validation
Include the vulkan validation layers in scenic even in release builds
TODO(SCN-1003): Set the default to false once we know why disabling
validation layers causes a display swapchain setup issue.

**Current value (from the default):** `true`

From [//garnet/bin/ui/BUILD.gn:12](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/ui/BUILD.gn#12)

### select_variant
List of "selectors" to request variant builds of certain targets.
Each selector specifies matching criteria and a chosen variant.
The first selector in the list to match a given target determines
which variant is used for that target.

Each selector is either a string or a scope.  A shortcut selector is
a string; it gets expanded to a full selector.  A full selector is a
scope, described below.

A string selector can match a name in
[`select_variant_shortcuts`](#select_variant_shortcuts).  If it's not a
specific shortcut listed there, then it can be the name of any variant
described in [`known_variants`](#known_variants) and
[`universal_variants`](#universal_variants) (and combinations thereof).
A `selector` that's a simple variant name selects for every binary
built in the target toolchain: `{ host=false variant=selector }`.

If a string selector contains a slash, then it's `"shortcut/filename"`
and selects only the binary in the target toolchain whose `output_name`
matches `"filename"`, i.e. it adds `output_name=["filename"]` to each
selector scope that the shortcut's name alone would yield.

The scope that forms a full selector defines some of these:

    variant (required)
        [string or `false`] The variant that applies if this selector
        matches.  This can be `false` to choose no variant, or a string
        that names the variant.  See
        [`known_variants`](#known_variants) and
        [`universal_variants`](#universal_variants).

The rest below are matching criteria.  All are optional.
The selector matches if and only if all of its criteria match.
If none of these is defined, then the selector always matches.

The first selector in the list to match wins and then the rest of
the list is ignored.  So construct more complex rules by using a
"blacklist" selector with `variant=false` before a catch-all or
"whitelist" selector that names a variant.

Each "[strings]" criterion is a list of strings, and the criterion
is satisfied if any of the strings matches against the candidate string.

    host
        [boolean] If true, the selector matches in the host toolchain.
        If false, the selector matches in the target toolchain.

    testonly
        [boolean] If true, the selector matches targets with testonly=true.
        If false, the selector matches in targets without testonly=true.

    target_type
        [strings]: `"executable"`, `"loadable_module"`, or `"driver_module"`

    output_name
        [strings]: target's `output_name` (default: its `target name`)

    label
        [strings]: target's full label with `:` (without toolchain suffix)

    name
        [strings]: target's simple name (label after last `/` or `:`)

    dir
        [strings]: target's label directory (`//dir` for `//dir:name`).

**Current value (from the default):** `[]`

From [//build/config/BUILDCONFIG.gn:613](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#613)

### shell_dart_version

**Current value (from the default):** `""`

From //third_party/flutter/shell/version/version.gni:10

### shell_engine_version

**Current value (from the default):** `""`

From //third_party/flutter/shell/version/version.gni:6

### skia_enable_gpu

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:49

### skia_use_opencl

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:33

### dart_core_snapshot_kind
Controls the kind of core snapshot linked into the standalone VM. Using a
core-jit snapshot breaks the ability to change various flags that affect
code generation.

**Current value (from the default):** `"core"`

From //third_party/dart/runtime/runtime_args.gni:58

### fuchsia_vulkan_sdk
Path to Fuchsia Vulkan SDK

**Current value (from the default):** `"//third_party/vulkan_loader_and_validation_layers"`

From [//build/vulkan/config.gni:10](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/vulkan/config.gni#10)

### host_byteorder

**Current value (from the default):** `"undefined"`

From [//build/config/host_byteorder.gni:7](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/host_byteorder.gni#7)

### skia_use_libpng

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:30

### use_prebuilt_webkit
Use a prebuilt WebKit binary rather than building it locally.
See [//topaz/runtime/web_view/README.md](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/web_view/README.md) for details on the prebuilt.
This is ignored when building WebKit-using components
such as `web_view` in variant builds (e.g. sanitizers).

**Current value (from the default):** `true`

From [//topaz/runtime/web_view/config.gni:10](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/web_view/config.gni#10)

### zircon_build_root

**Current value (from the default):** `"//zircon"`

From [//garnet/lib/magma/gnbuild/magma.gni:10](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#10)

### crashpad_dependencies

**Current value (from the default):** `"fuchsia"`

From [//third_party/crashpad/build/crashpad_buildconfig.gni:22](https://chromium.googlesource.com/crashpad/crashpad/+/411f0ae41d96518dfa9b75f58424d5d26eb7c75c/build/crashpad_buildconfig.gni#22)

### kernel_cmdline_files
Files containing additional kernel command line arguments to bake into
the boot image.  The contents of these files (in order) come after any
arguments directly in [`kernel_cmdline_args`](#kernel_cmdline_args).
These can be GN `//` source pathnames or absolute system pathnames.

**Current value (from the default):** `[]`

From [//build/images/BUILD.gn:355](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#355)

### skia_enable_flutter_defines

**Current value for `target_cpu = "arm64"`:** `true`

From //.gn:27

**Overridden from the default:** `false`

From //third_party/skia/BUILD.gn:19

**Current value for `target_cpu = "x64"`:** `true`

From //.gn:27

**Overridden from the default:** `false`

From //third_party/skia/BUILD.gn:19

### skia_lex

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:59

### skia_llvm_lib

**Current value (from the default):** `"LLVM"`

From //third_party/skia/BUILD.gn:65

### skia_use_libwebp

**Current value for `target_cpu = "arm64"`:** `false`

From //.gn:32

**Overridden from the default:** `false`

From //third_party/skia/BUILD.gn:31

**Current value for `target_cpu = "x64"`:** `false`

From //.gn:32

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:31

### dart_version_git_info
Whether the Dart binary version string should include the git hash and
git commit time.

**Current value (from the default):** `true`

From //third_party/dart/runtime/runtime_args.gni:62

### rust_toolchain_triple_suffix
Sets the fuchsia toolchain target triple suffix (after arch)

**Current value (from the default):** `"fuchsia"`

From [//build/rust/config.gni:23](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/rust/config.gni#23)

### skia_enable_spirv_validation

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:51

### known_variants
List of variants that will form the basis for variant toolchains.
To make use of a variant, set [`select_variant`](#select_variant).

Normally this is not set as a build argument, but it serves to
document the available set of variants.
See also [`universal_variants`](#universal_variants).
Only set this to remove all the default variants here.
To add more, set [`extra_variants`](#extra_variants) instead.

Each element of the list is one variant, which is a scope defining:

  `configs` (optional)
      [list of labels] Each label names a config that will be
      automatically used by every target built in this variant.
      For each config `${label}`, there must also be a target
      `${label}_deps`, which each target built in this variant will
      automatically depend on.  The `variant()` template is the
      recommended way to define a config and its `_deps` target at
      the same time.

  `remove_common_configs` (optional)
  `remove_shared_configs` (optional)
      [list of labels] This list will be removed (with `-=`) from
      the `default_common_binary_configs` list (or the
      `default_shared_library_configs` list, respectively) after
      all other defaults (and this variant's configs) have been
      added.

  `deps` (optional)
      [list of labels] Added to the deps of every target linked in
      this variant (as well as the automatic `${label}_deps` for
      each label in configs).

  `name` (required if configs is omitted)
      [string] Name of the variant as used in
      [`select_variant`](#select_variant) elements' `variant` fields.
      It's a good idea to make it something concise and meaningful when
      seen as e.g. part of a directory name under `$root_build_dir`.
      If name is omitted, configs must be nonempty and the simple names
      (not the full label, just the part after all `/`s and `:`s) of these
      configs will be used in toolchain names (each prefixed by a "-"),
      so the list of config names forming each variant must be unique
      among the lists in `known_variants + extra_variants`.

  `toolchain_args` (optional)
      [scope] Each variable defined in this scope overrides a
      build argument in the toolchain context of this variant.

  `host_only` (optional)
  `target_only` (optional)
      [scope] This scope can contain any of the fields above.
      These values are used only for host or target, respectively.
      Any fields included here should not also be in the outer scope.


**Current value (from the default):**
```
[{
  configs = ["//build/config/lto"]
}, {
  configs = ["//build/config/lto:thinlto"]
}, {
  configs = ["//build/config/profile"]
}, {
  configs = ["//build/config/scudo"]
}, {
  configs = ["//build/config/sanitizers:ubsan"]
}, {
  configs = ["//build/config/sanitizers:ubsan", "//build/config/sanitizers:sancov"]
}, {
  configs = ["//build/config/sanitizers:asan"]
  host_only = {
  remove_shared_configs = ["//build/config:symbol_no_undefined"]
}
  toolchain_args = {
  use_scudo = false
}
}, {
  configs = ["//build/config/sanitizers:asan", "//build/config/sanitizers:sancov"]
  host_only = {
  remove_shared_configs = ["//build/config:symbol_no_undefined"]
}
  toolchain_args = {
  use_scudo = false
}
}, {
  configs = ["//build/config/sanitizers:asan"]
  host_only = {
  remove_shared_configs = ["//build/config:symbol_no_undefined"]
}
  name = "asan_no_detect_leaks"
  toolchain_args = {
  asan_default_options = "detect_leaks=0"
  use_scudo = false
}
}, {
  configs = ["//build/config/sanitizers:asan", "//build/config/sanitizers:fuzzer"]
  host_only = {
  remove_shared_configs = ["//build/config:symbol_no_undefined"]
}
  remove_shared_configs = ["//build/config:symbol_no_undefined"]
  toolchain_args = {
  use_scudo = false
}
}, {
  configs = ["//build/config/sanitizers:ubsan", "//build/config/sanitizers:fuzzer"]
  remove_shared_configs = ["//build/config:symbol_no_undefined"]
}]
```

From [//build/config/BUILDCONFIG.gn:334](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#334)

### prebuilt_dart_sdk
Directory containing prebuilt Dart SDK.
This must have in its `bin/` subdirectory `gen_snapshot.OS-CPU` binaries.
Set to empty for a local build.

**Current value (from the default):** `"//topaz/tools/prebuilt-dart-sdk/linux-x64"`

From [//build/dart/dart.gni:9](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/dart/dart.gni#9)

### prebuilt_libvulkan_arm_path

**Current value (from the default):** `""`

From [//garnet/lib/magma/gnbuild/magma.gni:25](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#25)

### scudo_default_options
Default [Scudo](https://llvm.org/docs/ScudoHardenedAllocator.html)
options (before the `SCUDO_OPTIONS` environment variable is read at
runtime).  *NOTE:* This affects only components using the `scudo`
variant (see GN build argument `select_variant`), and does not affect
anything when the `use_scudo` build flag is set instead.

**Current value (from the default):** `["abort_on_error=1", "QuarantineSizeKb=0", "ThreadLocalQuarantineSizeKb=0", "DeallocationTypeMismatch=false", "DeleteSizeMismatch=false", "allocator_may_return_null=true"]`

From [//build/config/scudo/scudo.gni:15](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/scudo/scudo.gni#15)

### skia_enable_effects_imagefilters

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:46

### amlogic_decoder_tests

**Current value (from the default):** `false`

From [//garnet/drivers/video/amlogic-decoder/BUILD.gn:10](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/drivers/video/amlogic-decoder/BUILD.gn#10)

### build_vsl_gc

**Current value (from the default):** `true`

From [//garnet/lib/magma/gnbuild/magma.gni:22](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#22)

### core_jit_cheat_target

**Current value (from the default):** `""`

From [//topaz/runtime/flutter_runner/kernel/BUILD.gn:27](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/flutter_runner/kernel/BUILD.gn#27)

### zircon_asan_build_dir
Zircon `USE_ASAN=true` build directory for `target_cpu` containing
`bootfs.manifest` with libraries and `devhost.asan`.

If left `""` (the default), then this is computed from
[`zircon_build_dir`](#zircon_build_dir) and
[`zircon_use_asan`](#zircon_use_asan).

**Current value (from the default):** `""`

From [//build/config/fuchsia/zircon.gni:32](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/fuchsia/zircon.gni#32)

### zircon_boot_groups
Groups to include from the Zircon /boot manifest into /boot.
This is either "all" or a comma-separated list of one or more of:
  core -- necessary to boot
  misc -- utilities in /bin
  test -- test binaries in /bin and /test

**Current value (from the default):** `"core"`

From [//build/images/BUILD.gn:25](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#25)

### zircon_tools_dir
Where to find Zircon's host-side tools that are run as part of the build.

**Current value (from the default):** `"//out/build-zircon/tools"`

From [//build/config/fuchsia/zircon.gni:9](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/fuchsia/zircon.gni#9)

### skia_enable_vulkan_debug_layers

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:54

### skia_use_icu

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:28

### use_prebuilt_ffmpeg
Use a prebuilt ffmpeg binary rather than building it locally.  See
[//garnet/bin/mediaplayer/ffmpeg/README.md](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/mediaplayer/ffmpeg/README.md) for details.  This is
ignored when building media_player in variant builds (e.g. sanitizers);
in that case, ffmpeg is always built from source so as to be built with
the selected variant's config.  When this is false (either explicitly
or because media_player is a variant build) then //third_party/ffmpeg
must be in the source tree, which requires:
`jiri import -name garnet manifest/ffmpeg https://fuchsia.googlesource.com/garnet`

**Current value (from the default):** `true`

From [//garnet/bin/mediaplayer/ffmpeg/BUILD.gn:14](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/mediaplayer/ffmpeg/BUILD.gn#14)

### skia_qt_path

**Current value (from the default):** `""`

From //third_party/skia/BUILD.gn:56

### use_thinlto
Use ThinLTO variant of LTO if use_lto = true.

**Current value (from the default):** `true`

From [//build/config/lto/config.gni:10](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/lto/config.gni#10)

### current_cpu

**Current value (from the default):** `""`

### flutter_default_app

**Current value (from the default):** `"flutter_jit_app"`

From [//topaz/runtime/dart/dart_component.gni:13](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/dart/dart_component.gni#13)

### host_tools_dir
This is the directory where host tools intended for manual use by
developers get installed.  It's something a developer might put
into their shell's $PATH.  Host tools that are just needed as part
of the build do not get copied here.  This directory is only for
things that are generally useful for testing or debugging or
whatnot outside of the GN build itself.  These are only installed
by an explicit install_host_tools() rule (see [//build/host.gni](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/host.gni)).

**Current value (from the default):** `"//root_build_dir/tools"`

From [//build/host.gni:13](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/host.gni#13)

### skia_llvm_path

**Current value (from the default):** `""`

From //third_party/skia/BUILD.gn:64

### skia_use_angle

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:23

### amber_repository_blobs_dir

**Current value (from the default):** `"//root_build_dir/amber-files/repository/blobs"`

From [//garnet/go/src/pm/pm.gni:16](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/go/src/pm/pm.gni#16)

### dart_custom_version_for_pub
When this argument is a non-empty string, the version repoted by the
Dart VM will be one that is compatible with pub's interpretation of
semantic version strings. The version string will also include the values
of the argument. In particular the version string will read:

    "M.m.p-dev.x.x-$(dart_custom_version_for_pub)-$(short_git_hash)"

Where 'M', 'm', and 'p' are the major, minor and patch version numbers,
and 'dev.x.x' is the dev version tag most recently preceeding the current
revision. The short git hash can be omitted by setting
dart_version_git_info=false

**Current value (from the default):** `""`

From //third_party/dart/runtime/runtime_args.gni:75

### host_os

**Current value (from the default):** `"linux"`

### kernel_cmdline_args
List of kernel command line arguments to bake into the boot image.
See also [//zircon/docs/kernel_cmdline.md](https://fuchsia.googlesource.com/zircon/+/cb56569a8270931be156ba1a82ddf603cd8707c7/docs/kernel_cmdline.md) and
[`devmgr_config`](#devmgr_config).

**Current value (from the default):** `[]`

From [//build/images/BUILD.gn:349](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#349)

### scenic_ignore_vsync

**Current value (from the default):** `false`

From [//garnet/lib/ui/gfx/BUILD.gn:16](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/ui/gfx/BUILD.gn#16)

### skia_tools_require_resources

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:67

### skia_use_freetype

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:27

### target_os

**Current value (from the default):** `""`

### enable_crashpad
When this is set, Crashpad will be used to handle exceptions (which uploads
crashes to the crash server), rather than crashanalyzer in Zircon (which
prints the crash log to the the system log).

**Current value (from the default):** `false`

From [//build/images/crashpad.gni:9](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/crashpad.gni#9)

### flutter_profile

**Current value (from the default):** `true`

From [//topaz/runtime/dart/dart_component.gni:38](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/dart/dart_component.gni#38)

### fuchsia_use_vulkan
Consolidated build toggle for use of Vulkan across Fuchsia

**Current value (from the default):** `true`

From [//build/vulkan/config.gni:7](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/vulkan/config.gni#7)

### flutter_runtime_mode
The runtime mode ("debug", "profile", "release", "dynamic_profile", or "dynamic_release")

**Current value (from the default):** `"debug"`

From //third_party/flutter/common/config.gni:18

### magma_build_root

**Current value (from the default):** `"//garnet/lib/magma"`

From [//garnet/lib/magma/gnbuild/magma.gni:6](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#6)

### skia_enable_skottie

**Current value (from the default):** `true`

From //third_party/skia/modules/skottie/BUILD.gn:7

### skia_enable_tools

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:53

### skia_use_egl

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:24

### dart_pool_depth
Maximum number of Dart processes to run in parallel.

Dart analyzer uses a lot of memory which may cause issues when building
with many parallel jobs e.g. when using goma. To avoid out-of-memory
errors we explicitly reduce the number of jobs.

**Current value (from the default):** `16`

From [//build/dart/toolchain.gni:11](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/dart/toolchain.gni#11)

### embedder_for_target
By default, the dynamic library target exposing the embedder API is only
built for the host. The reasoning is that platforms that have target
definitions would not need an embedder API because an embedder
implementation is already provided for said target. This flag allows tbe
builder to obtain a shared library exposing the embedder API for alternative
embedder implementations.

**Current value (from the default):** `false`

From //third_party/flutter/shell/platform/embedder/embedder.gni:12

### expat_build_root

**Current value (from the default):** `"//third_party/expat"`

From [//garnet/lib/magma/gnbuild/magma.gni:7](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#7)

### skia_use_fontconfig

**Current value for `target_cpu = "arm64"`:** `false`

From //.gn:31

**Overridden from the default:** `false`

From //third_party/skia/BUILD.gn:26

**Current value for `target_cpu = "x64"`:** `false`

From //.gn:31

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:26

### vk_loader_debug

**Current value (from the default):** `"warn,error"`

From [//third_party/vulkan_loader_and_validation_layers/loader/BUILD.gn:26](https://fuchsia.googlesource.com/third_party/vulkan_loader_and_validation_layers/+/3106666ca09bdab1a0f3c4c5d4d614bf4dab1f3d/loader/BUILD.gn#26)

### zircon_aux_manifests

**Current value (from the default):** `["//out/build-zircon/build-arm64-asan/bootfs.manifest"]`

From [//build/images/manifest.gni:32](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/manifest.gni#32)

### toolchain_variant
*This should never be set as a build argument.*
It exists only to be set in `toolchain_args`.
See [//build/toolchain/clang_toolchain.gni](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/toolchain/clang_toolchain.gni) for details.
This variable is a scope giving details about the current toolchain:
    `toolchain_variant.base`
        [label] The "base" toolchain for this variant, *often the
        right thing to use in comparisons, not `current_toolchain`.*
        This is the toolchain actually referenced directly in GN
        source code.  If the current toolchain is not
        `shlib_toolchain` or a variant toolchain, this is the same
        as `current_toolchain`.  In one of those derivative
        toolchains, this is the toolchain the GN code probably
        thought it was in.  This is the right thing to use in a test
        like `toolchain_variant.base == target_toolchain`, rather
        rather than comparing against `current_toolchain`.
    `toolchain_variant.name`
        [string] The name of this variant, as used in `variant` fields
        in [`select_variant`](#select_variant) clauses.  In the base
        toolchain and its `shlib_toolchain`, this is `""`.
    `toolchain_variant.suffix`
        [string] This is "-${toolchain_variant.name}", "" if name is empty.
    `toolchain_variant.is_pic_default`
        [bool] This is true in `shlib_toolchain`.
The other fields are the variant's effects as defined in
[`known_variants`](#known_variants).

**Current value (from the default):**
```
{
  base = "//build/toolchain/fuchsia:arm64"
}
```

From [//build/config/BUILDCONFIG.gn:71](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#71)

### use_scudo
Enable the [Scudo](https://llvm.org/docs/ScudoHardenedAllocator.html)
memory allocator.

**Current value (from the default):** `true`

From [//build/config/scudo/scudo.gni:8](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/scudo/scudo.gni#8)

### dart_component_kind
Allow for deduping the VM between standalone, flutter_runner and dart_runner.

**Current value (from the default):** `"shared_library"`

From //third_party/dart/runtime/runtime_args.gni:80

### magma_python_path

**Current value (from the default):** `"/b/s/w/ir/kitchen-workdir/third_party/mako"`

From [//garnet/lib/magma/gnbuild/magma.gni:12](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#12)

### symbol_level
How many symbols to include in the build. This affects the performance of
the build since the symbols are large and dealing with them is slow.
  2 means regular build with symbols.
  1 means minimal symbols, usually enough for backtraces only. Symbols with
internal linkage (static functions or those in anonymous namespaces) may not
appear when using this level.
  0 means no symbols.

**Current value (from the default):** `2`

From [//build/config/compiler.gni:13](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/compiler.gni#13)

### skia_use_x11

**Current value for `target_cpu = "arm64"`:** `false`

From //.gn:34

**Overridden from the default:** `false`

From //third_party/skia/BUILD.gn:39

**Current value for `target_cpu = "x64"`:** `false`

From //.gn:34

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:39

### use_goma
Set to true to enable distributed compilation using Goma.

**Current value (from the default):** `false`

From [//build/toolchain/goma.gni:9](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/toolchain/goma.gni#9)

### host_cpu

**Current value (from the default):** `"x64"`

### skia_enable_atlas_text

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:72

### skia_skqp_enable_driver_correctness_workarounds

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:61

### exclude_kernel_service
Whether the VM includes the kernel service in all modes (debug, release,
product).

**Current value (from the default):** `false`

From //third_party/dart/runtime/runtime_args.gni:90

### is_debug
Debug build.

**Current value (from the default):** `true`

From [//build/config/BUILDCONFIG.gn:11](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#11)

### skia_enable_fontmgr_empty

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:48

### sdk_dirs
The directories to search for parts of the SDK.

By default, we search the public directories for the various layers.
In the future, we'll search a pre-built SDK as well.

**Current value (from the default):** `["//garnet/public", "//peridot/public", "//topaz/public"]`

From [//build/config/fuchsia/sdk.gni:10](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/fuchsia/sdk.gni#10)

### skia_compile_processors

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:57

### zedboot_devmgr_config
List of arguments to populate /boot/config/devmgr in the Zedboot image.

**Current value (from the default):** `["netsvc.netboot=true"]`

From [//build/images/zedboot/BUILD.gn:24](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/zedboot/BUILD.gn#24)

### build_intel_gen

**Current value (from the default):** `false`

From [//garnet/lib/magma/gnbuild/magma.gni:23](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#23)

### enable_gfx_subsystem

**Current value (from the default):** `true`

From [//garnet/bin/ui/scenic/BUILD.gn:12](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/ui/scenic/BUILD.gn#12)

### msd_intel_gen_build_root

**Current value (from the default):** `"//garnet/drivers/gpu/msd-intel-gen"`

From [//garnet/lib/magma/gnbuild/magma.gni:8](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#8)

### dart_target_arch
Explicitly set the target architecture to use a simulator.
Available options are: arm, arm64, x64, ia32, and dbc.

**Current value (from the default):** `"arm64"`

From //third_party/dart/runtime/runtime_args.gni:32

### escher_use_null_vulkan_config_on_host
Using Vulkan on host (i.e. Linux) is an involved affair that involves
downloading the Vulkan SDK, setting environment variables, and so forth...
all things that are difficult to achieve in a CQ environment.  Therefore,
by default we use a stub implementation of Vulkan which fails to create a
VkInstance.  This allows everything to build, and also allows running Escher
unit tests which don't require Vulkan.

**Current value (from the default):** `true`

From [//garnet/public/lib/escher/BUILD.gn:15](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/public/lib/escher/BUILD.gn#15)

### skia_use_vulkan

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:77

### universal_variants

**Current value (from the default):**
```
[{
  configs = []
  name = "release"
  toolchain_args = {
  is_debug = false
}
}]
```

From [//build/config/BUILDCONFIG.gn:413](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILDCONFIG.gn#413)

### use_vulkan_loader_for_tests
Mesa doesn't properly handle loader-less operation;
their GetInstanceProcAddr implementation returns 0 for some interfaces.
On ARM there may be multiple libvulkan_arms, so they can't all be linked
to.

**Current value (from the default):** `true`

From [//garnet/lib/magma/gnbuild/magma.gni:33](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#33)

### armadillo_path_context_config

**Current value (from the default):** `"../bin/user_shell/armadillo_user_shell/assets/contextual_config.json"`

From [//topaz/shell/BUILD.gn:14](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/shell/BUILD.gn#14)

### core_jit_cheat_trace

**Current value (from the default):** `""`

From [//topaz/runtime/flutter_runner/kernel/BUILD.gn:28](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/flutter_runner/kernel/BUILD.gn#28)

### current_os

**Current value (from the default):** `""`

### zircon_boot_manifests
Manifest files describing files to go into the `/boot` filesystem.
Can be either // source paths or absolute system paths.
`zircon_boot_groups` controls which files are actually selected.

Since Zircon manifest files are relative to a Zircon source directory
rather than to the directory containing the manifest, these are assumed
to reside in a build directory that's a direct subdirectory of the
Zircon source directory and thus their contents can be taken as
relative to `get_path_info(entry, "dir") + "/.."`.

**Current value (from the default):** `["//out/build-zircon/build-arm64/bootfs.manifest"]`

From [//build/images/manifest.gni:44](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/manifest.gni#44)

### build_msd_arm_mali

**Current value (from the default):** `true`

From [//garnet/lib/magma/gnbuild/magma.gni:21](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#21)

### enable_input_subsystem

**Current value (from the default):** `true`

From [//garnet/bin/ui/scenic/BUILD.gn:14](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/ui/scenic/BUILD.gn#14)

### experimental_web_entity_extraction

**Current value (from the default):** `false`

From [//topaz/runtime/web_view/config.gni:12](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/web_view/config.gni#12)

### skia_enable_ccpr

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:42

### zircon_build_abi_dir
Zircon build directory for `target_cpu`, containing link-time `.so.abi`
files that GN `deps` on [//zircon/public](https://fuchsia.googlesource.com/zircon/+/cb56569a8270931be156ba1a82ddf603cd8707c7/public) libraries will link against.
This should not be a sanitizer build.

**Current value (from the default):** `"//out/build-zircon/build-arm64"`

From [//build/config/fuchsia/zircon.gni:14](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/fuchsia/zircon.gni#14)

### dart_use_tcmalloc
Whether to link the standalone VM against tcmalloc. The standalone build of
the VM enables this only for Linux builds.

**Current value (from the default):** `false`

From //third_party/dart/runtime/runtime_args.gni:53

### enable_sketchy_subsystem

**Current value (from the default):** `true`

From [//garnet/bin/ui/scenic/BUILD.gn:13](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/bin/ui/scenic/BUILD.gn#13)

### rustc_prefix
Sets a custom base directory for `rustc` and `cargo`.
This can be used to test custom Rust toolchains.

**Current value (from the default):** `"//buildtools/linux-x64/rust/bin"`

From [//build/rust/config.gni:17](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/rust/config.gni#17)

### dart_use_fallback_root_certificates
Whether to fall back to built-in root certificates when they cannot be
verified at the operating system level.

**Current value (from the default):** `false`

From //third_party/dart/runtime/runtime_args.gni:43

### fuchsia_products
List of product definition files describing the packages to build, and
where they are to be installed in images and updates.

A product definition file is a JSON file containing:
monolith:
  a list of packages included in OTA images, base system images, and the
  distribution repository.
preinstall:
  a list of packages pre-installed on the system (also added to the
  distribution repository)
available:
  a list of packages only added to the distribution repository)

If a package is referenced in monolith and in preinstall, monolith takes
priority, and the package will be added to OTA images as part of the
verified boot set of static packages.

If unset, layer will be guessed using //.jiri_manifest and
//{layer}/products/default will be used.

**Current value (from the default):** `[]`

From [//build/gn/packages.gni:25](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/gn/packages.gni#25)

### skia_generate_workarounds

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:58

### skia_use_sfntly

**Current value for `target_cpu = "arm64"`:** `false`

From //.gn:33

**Overridden from the default:** `false`

From //third_party/skia/BUILD.gn:71

**Current value for `target_cpu = "x64"`:** `false`

From //.gn:33

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:71

### target_sysroot
The absolute path of the sysroot that is used with the target toolchain.

**Current value (from the default):** `""`

From [//build/config/sysroot.gni:7](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/sysroot.gni#7)

### build_sdk_archives
Whether to build SDK tarballs.

**Current value (from the default):** `false`

From [//build/sdk/sdk.gni:11](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/sdk/sdk.gni#11)

### crashpad_use_boringssl_for_http_transport_socket

**Current value (from the default):** `true`

From [//third_party/crashpad/util/net/tls.gni:18](https://chromium.googlesource.com/crashpad/crashpad/+/411f0ae41d96518dfa9b75f58424d5d26eb7c75c/util/net/tls.gni#18)

### dart_aot_sharing_basis
module_suggester is not AOT compiled in debug builds

**Current value (from the default):** `""`

From [//topaz/runtime/dart/dart_component.gni:54](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/dart/dart_component.gni#54)

### zircon_asserts

**Current value (from the default):** `true`

From [//build/config/fuchsia/BUILD.gn:138](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/fuchsia/BUILD.gn#138)

### target_cpu

**Current value for `target_cpu = "arm64"`:** `"arm64"`

From //root_build_dir/args.gn:1

**Overridden from the default:** `""`

**Current value for `target_cpu = "x64"`:** `"x64"`

From //root_build_dir/args.gn:1

**Overridden from the default:** `""`

### magma_enable_tracing
Enable this to include fuchsia tracing capability

**Current value (from the default):** `true`

From [//garnet/lib/magma/gnbuild/magma.gni:15](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#15)

### skia_enable_discrete_gpu

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:44

### skia_vulkan_header

**Current value (from the default):** `""`

From //third_party/skia/BUILD.gn:55

### fvm_image_size
The size in bytes of the FVM partition image to create. Normally this is
computed to be just large enough to fit the blob and data images. The
default value is "", which means to size based on inputs. Specifying a size
that is too small will result in build failure.

**Current value (from the default):** `""`

From [//build/images/BUILD.gn:574](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/BUILD.gn#574)

### glm_build_root

**Current value (from the default):** `"//third_party/glm"`

From [//garnet/lib/magma/gnbuild/magma.gni:9](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#9)

### magma_enable_developer_build
Enable this to have the msd include a suite of tests and invoke them
automatically when the driver starts.

**Current value (from the default):** `false`

From [//garnet/lib/magma/gnbuild/magma.gni:19](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#19)

### shell_enable_vulkan

**Current value (from the default):** `false`

From //third_party/flutter/shell/config.gni:6

### skia_use_expat

**Current value for `target_cpu = "arm64"`:** `false`

From //.gn:30

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:25

**Current value for `target_cpu = "x64"`:** `false`

From //.gn:30

**Overridden from the default:** `true`

From //third_party/skia/BUILD.gn:25

### dart_vm_code_coverage
Whether to enable code coverage for the standalone VM.

**Current value (from the default):** `false`

From //third_party/dart/runtime/runtime_args.gni:39

### enable_frame_pointers
Controls whether the compiler emits full stack frames for function calls.
This reduces performance but increases the ability to generate good
stack traces, especially when we have bugs around unwind table generation.
It applies only for Fuchsia targets (see below where it is unset).

TODO(ZX-2361): Theoretically unwind tables should be good enough so we can
remove this option when the issues are addressed.

**Current value (from the default):** `true`

From [//build/config/BUILD.gn:16](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/BUILD.gn#16)

### flutter_aot_sharing_basis
Armadillo is not AOT compiled in debug builds

**Current value (from the default):** `""`

From [//topaz/runtime/dart/dart_component.gni:30](https://fuchsia.googlesource.com/topaz/+/8d349739d0b5b09d786ac4e3782200421ad409a8/runtime/dart/dart_component.gni#30)

### system_package_key
The package key to use for signing Fuchsia packages made by the
`package()` template (and the `system_image` packge).  If this
doesn't exist yet when it's needed, it will be generated.  New
keys can be generated with the `pm -k FILE genkey` host command.

**Current value (from the default):** `"//build/development.key"`

From [//build/package.gni:16](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/package.gni#16)

### skia_use_libheif

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:38

### skia_use_lua

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:32

### skia_use_piex

**Current value (from the default):** `true`

From //third_party/skia/BUILD.gn:34

### icu_use_data_file
Tells icu to load an external data file rather than rely on the icudata
being linked directly into the binary.

This flag is a bit confusing. As of this writing, icu.gyp set the value to
0 but common.gypi sets the value to 1 for most platforms (and the 1 takes
precedence).

TODO(GYP) We'll probably need to enhance this logic to set the value to
true or false in similar circumstances.

**Current value (from the default):** `true`

From [//third_party/icu/config.gni:15](https://fuchsia.googlesource.com/third_party/icu/+/15006476e9d2f5c7d6691f3658fecff4929aaf68/config.gni#15)

### use_ccache
Set to true to enable compiling with ccache

**Current value (from the default):** `false`

From [//build/toolchain/ccache.gni:9](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/toolchain/ccache.gni#9)

### zedboot_cmdline_files
Files containing additional kernel command line arguments to bake into
the Zedboot image.  The contents of these files (in order) come after any
arguments directly in [`zedboot_cmdline_args`](#zedboot_cmdline_args).
These can be GN `//` source pathnames or absolute system pathnames.

**Current value (from the default):** `[]`

From [//build/images/zedboot/BUILD.gn:21](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/zedboot/BUILD.gn#21)

### skia_skqp_global_error_tolerance

**Current value (from the default):** `0`

From //third_party/skia/BUILD.gn:62

### skia_use_metal

**Current value (from the default):** `false`

From //third_party/skia/BUILD.gn:37

### use_lto
Use link time optimization (LTO).

**Current value (from the default):** `false`

From [//build/config/lto/config.gni:7](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/lto/config.gni#7)

### create_kernel_service_snapshot

**Current value (from the default):** `false`

From //third_party/dart/runtime/runtime_args.gni:103

### goma_dir
Absolute directory containing the Goma source code.

**Current value (from the default):** `"/home/swarming/goma"`

From [//build/toolchain/goma.gni:12](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/toolchain/goma.gni#12)

### skia_android_serial

**Current value (from the default):** `""`

From //third_party/skia/BUILD.gn:41

### custom_signing_script
If non-empty, the given script will be invoked to produce a signed ZBI
image. The given script must accept -z for the input zbi path, and -o for
the output signed zbi path. The path must be in GN-label syntax (i.e.
starts with //).

**Current value (from the default):** `""`

From [//build/images/custom_signing.gni:10](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/images/custom_signing.gni#10)

## `target_cpu = "arm64"`

### arm_optionally_use_neon
Whether to enable optional NEON code paths.

**Current value (from the default):** `false`

From [//build/config/arm.gni:31](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/arm.gni#31)

### arm_tune
The ARM variant-specific tuning mode. This will be a string like "armv6"
or "cortex-a15". An empty string means to use the default for the
arm_version.

**Current value (from the default):** `""`

From [//build/config/arm.gni:25](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/arm.gni#25)

### arm_use_neon
Whether to use the neon FPU instruction set or not.

**Current value (from the default):** `true`

From [//build/config/arm.gni:28](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/arm.gni#28)

### arm_version

**Current value (from the default):** `8`

From [//build/config/arm.gni:12](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/arm.gni#12)

### msd_arm_enable_all_cores
Enable all 8 cores, which is faster but emits more heat.

**Current value (from the default):** `true`

From [//garnet/drivers/gpu/msd-arm-mali/src/BUILD.gn:9](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/drivers/gpu/msd-arm-mali/src/BUILD.gn#9)

### msd_arm_enable_cache_coherency
With this flag set the system tries to use cache coherent memory if the
GPU supports it.

**Current value (from the default):** `true`

From [//garnet/drivers/gpu/msd-arm-mali/src/BUILD.gn:13](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/drivers/gpu/msd-arm-mali/src/BUILD.gn#13)

### arm_float_abi
The ARM floating point mode. This is either the string "hard", "soft", or
"softfp". An empty string means to use the default one for the
arm_version.

**Current value (from the default):** `""`

From [//build/config/arm.gni:20](https://fuchsia.googlesource.com/build/+/3fdbc8cb3efc603d7d08d93395929b6420b7e973/config/arm.gni#20)

## `target_cpu = "x64"`

### mesa_build_root

**Current value (from the default):** `"//third_party/mesa"`

From [//garnet/lib/magma/gnbuild/magma.gni:41](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/lib/magma/gnbuild/magma.gni#41)

### msd_intel_enable_mapping_cache

**Current value (from the default):** `false`

From [//garnet/drivers/gpu/msd-intel-gen/src/BUILD.gn:8](https://fuchsia.googlesource.com/garnet/+/26a3728ed97abb084dd932d715a9fc7f2cb6150d/drivers/gpu/msd-intel-gen/src/BUILD.gn#8)

### use_mock_magma

**Current value (from the default):** `false`

From [//third_party/mesa/src/intel/vulkan/BUILD.gn:25](https://fuchsia.googlesource.com/third_party/mesa/+/2f2abaa7aa5ab971d80c831f077df11747790d1f/src/intel/vulkan/BUILD.gn#25)

