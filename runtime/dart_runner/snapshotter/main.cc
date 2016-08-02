// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fcntl.h>

#include <iostream>
#include <set>
#include <string>

#include "apps/dart_content_handler/embedder/snapshot.h"
#include "apps/dart_content_handler/zip/zipper.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/command_line.h"
#include "lib/ftl/files/directory.h"
#include "lib/ftl/files/eintr_wrapper.h"
#include "lib/ftl/files/file_descriptor.h"
#include "lib/ftl/files/file.h"
#include "lib/ftl/files/symlink.h"
#include "lib/ftl/files/unique_fd.h"
#include "lib/ftl/logging.h"
#include "lib/tonic/file_loader/file_loader.h"
#include "lib/tonic/file_loader/string_converter.h"

namespace dart_snapshotter {
namespace {

using tonic::StringFromDart;
using tonic::StringToDart;

constexpr char kHelp[] = "help";
constexpr char kPackages[] = "packages";
constexpr char kSnapshot[] = "snapshot";
constexpr char kDartX[] = "dartx";
constexpr char kDepfile[] = "depfile";
constexpr char kBuildOutput[] = "build-output";

constexpr char kShebang[] = "#!mojo mojo:dart_content_handler\n";
constexpr size_t kShebangLength = sizeof(kShebang) - 1;

constexpr char kSnapshotKey[] = "snapshot_blob.bin";

const char* kDartArgs[] = {
    "--enable_mirrors=false",
};

void Usage() {
  std::cerr
      << "Usage: dart_snapshotter --" << kPackages << "=PACKAGES" << std::endl
      << "                        --" << kDartX << "OUTPUT_BUNDLE" << std::endl
      << "                      [ --" << kSnapshot << "=OUTPUT_SNAPSHOT ]"
      << std::endl
      << "                      [ --" << kDepfile << "=DEPFILE ]" << std::endl
      << "                      [ --" << kBuildOutput << "=BUILD_OUTPUT ]"
      << std::endl
      << std::endl
      << "                        MAIN_DART" << std::endl
      << " * PACKAGES is the '.packages' file that defines where to find Dart "
         "packages."
      << std::endl
      << " * OUTPUT_BUNDLE is the file to write the '.dartx' bundle into."
      << std::endl
      << " * OUTPUT_SNAPSHOT is the file to write the snapshot into."
      << std::endl
      << " * DEPFILE is the file into which to write the '.d' depedendency "
         "information into."
      << std::endl
      << " * BUILD_OUTPUT determines the target name used in the " << std::endl
      << "   DEPFILE. (Required if DEPFILE is provided.) " << std::endl;
}

class DartScope {
 public:
  DartScope(Dart_Isolate isolate) {
    Dart_EnterIsolate(isolate);
    Dart_EnterScope();
  }

  ~DartScope() {
    Dart_ExitScope();
    Dart_ExitIsolate();
  }
};

void InitDartVM() {
  FTL_CHECK(Dart_SetVMFlags(arraysize(kDartArgs), kDartArgs));
  char* error =
      Dart_Initialize(dart_content_handler::vm_isolate_snapshot_buffer, nullptr,
                      nullptr, nullptr, nullptr, nullptr, nullptr, nullptr,
                      nullptr, nullptr, nullptr, nullptr, nullptr, nullptr);
  if (error)
    FTL_LOG(FATAL) << error;
}

Dart_Isolate CreateDartIsolate() {
  FTL_CHECK(dart_content_handler::isolate_snapshot_buffer);
  char* error = nullptr;
  Dart_Isolate isolate = Dart_CreateIsolate(
      "dart:snapshot", "main", dart_content_handler::isolate_snapshot_buffer,
      nullptr, nullptr, &error);
  FTL_CHECK(isolate) << error;
  Dart_ExitIsolate();
  return isolate;
}

tonic::FileLoader* g_loader = nullptr;

tonic::FileLoader& GetLoader() {
  if (!g_loader)
    g_loader = new tonic::FileLoader();
  return *g_loader;
}

Dart_Handle HandleLibraryTag(Dart_LibraryTag tag,
                             Dart_Handle library,
                             Dart_Handle url) {
  FTL_CHECK(Dart_IsLibrary(library));
  FTL_CHECK(Dart_IsString(url));
  tonic::FileLoader& loader = GetLoader();
  if (tag == Dart_kCanonicalizeUrl)
    return loader.CanonicalizeURL(library, url);
  if (tag == Dart_kImportTag)
    return loader.Import(url);
  if (tag == Dart_kSourceTag)
    return loader.Source(library, url);
  return Dart_NewApiError("Unknown library tag.");
}

std::vector<char> CreateSnapshot() {
  uint8_t* buffer = nullptr;
  intptr_t size = 0;
  DART_CHECK_VALID(Dart_CreateScriptSnapshot(&buffer, &size));
  const char* begin = reinterpret_cast<const char*>(buffer);
  return std::vector<char>(begin, begin + size);
}

bool WriteDepfile(const std::string& path,
                  const std::string& build_output,
                  const std::set<std::string>& deps) {
  std::string current_directory = files::GetCurrentDirectory();
  std::string output = build_output + ":";
  for (const auto& dep : deps) {
    std::string file = dep;
    FTL_DCHECK(!file.empty());
    if (file[0] != '/')
      file = current_directory + "/" + file;

    std::string resolved_file;
    if (files::ReadSymbolicLink(file, &resolved_file)) {
      output += " " + resolved_file;
    } else {
      output += " " + file;
    }
  }
  return files::WriteFile(path, output.data(), output.size());
}

bool WriteBundle(const std::string& path, const char* archive, size_t size) {
  ftl::UniqueFD fd(HANDLE_EINTR(creat(path.c_str(), 0666)));
  if (!fd.is_valid())
    return false;
  return ftl::WriteFileDescriptor(fd.get(), kShebang, kShebangLength) &&
         ftl::WriteFileDescriptor(fd.get(), archive, size);
}

int CreateSnapshot(const ftl::CommandLine& command_line) {
  if (command_line.HasOption(kHelp, nullptr)) {
    Usage();
    return 0;
  }

  if (command_line.positional_args().empty()) {
    Usage();
    return 1;
  }

  std::string packages;
  if (!command_line.GetOptionValue(kPackages, &packages)) {
    std::cerr << "error: Need --" << kPackages << std::endl;
    return 1;
  }

  std::vector<std::string> args = command_line.positional_args();
  if (args.size() != 1) {
    std::cerr << "error: Need one position argument. Got " << args.size() << "."
              << std::endl;
    return 1;
  }

  std::string main_dart = args[0];

  std::string bundle;
  command_line.GetOptionValue(kDartX, &bundle);

  std::string snapshot;
  command_line.GetOptionValue(kSnapshot, &snapshot);

  if (bundle.empty() && snapshot.empty()) {
    std::cerr << "error: Need --" << kDartX << " or --" << kSnapshot << "."
              << std::endl;
    return 1;
  }

  std::string depfile;
  std::string build_output;
  if (command_line.GetOptionValue(kDepfile, &depfile) &&
      !command_line.GetOptionValue(kBuildOutput, &build_output)) {
    std::cerr << "error: Need --" << kBuildOutput << " if --" << kDepfile
              << " is specified." << std::endl;
    return 1;
  }

  InitDartVM();

  tonic::FileLoader& loader = GetLoader();
  if (!loader.LoadPackagesMap(packages))
    return 1;

  Dart_Isolate isolate = CreateDartIsolate();
  FTL_CHECK(isolate) << "Failed to create isolate.";

  DartScope scope(isolate);

  DART_CHECK_VALID(Dart_SetLibraryTagHandler(HandleLibraryTag));
  DART_CHECK_VALID(Dart_LoadScript(StringToDart(main_dart), Dart_Null(),
                                   StringToDart(loader.Fetch(main_dart)), 0,
                                   0));

  std::vector<char> snapshot_blob = CreateSnapshot();

  if (!snapshot.empty() &&
      !files::WriteFile(snapshot, snapshot_blob.data(), snapshot_blob.size())) {
    std::cerr << "error: Failed to write snapshot to '" << snapshot << "'."
              << std::endl;
    return 1;
  }

  if (!bundle.empty()) {
    zip::Zipper zipper;
    if (!zipper.AddCompressedFile(kSnapshotKey, snapshot_blob.data(),
                                  snapshot_blob.size()))
      return 1;
    std::vector<char> bundle_blob = zipper.Finish();
    if (!WriteBundle(bundle, bundle_blob.data(), bundle_blob.size())) {
      std::cerr << "error: Failed to write dartx bundle to '" << bundle << "'."
                << std::endl;
      return 1;
    }
  }

  if (!depfile.empty() &&
      !WriteDepfile(depfile, build_output, loader.dependencies())) {
    std::cerr << "error: Failed to write depfile to '" << depfile << "'."
              << std::endl;
    return 1;
  }

  return 0;
}

}  // namespace
}  // namespace dart_snapshotter

int main(int argc, const char* argv[]) {
  return dart_snapshotter::CreateSnapshot(
      ftl::CommandLineFromArgcArgv(argc, argv));
}
