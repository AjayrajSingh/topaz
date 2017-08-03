// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fcntl.h>

#include <iostream>
#include <set>
#include <string>

#include "lib/ftl/arraysize.h"
#include "lib/ftl/command_line.h"
#include "lib/ftl/files/directory.h"
#include "lib/ftl/files/eintr_wrapper.h"
#include "lib/ftl/files/file.h"
#include "lib/ftl/files/file_descriptor.h"
#include "lib/ftl/files/symlink.h"
#include "lib/ftl/files/unique_fd.h"
#include "lib/ftl/logging.h"

namespace dart_snapshotter {
namespace {

constexpr char kHelp[] = "help";
constexpr char kInterpreter[] = "interpreter";
constexpr char kSnapshotKey[] = "snapshot-key";
constexpr char kSnapshot[] = "snapshot";
constexpr char kBundle[] = "bundle";

void Usage() {
  std::cerr << "Usage: dart_bundler --" << kInterpreter << "=INTERPRETER"
            << std::endl
            << "                    --" << kSnapshotKey << "=SNAPSHOT_KEY"
            << std::endl
            << "                    --" << kSnapshot << "=INPUT_SNAPSHOT"
            << std::endl
            << "                    --" << kBundle << "=OUTPUT_BUNDLE"
            << std::endl;
}

bool WriteBundle(const std::string& path,
                 const std::string& interpreter_line,
                 const char* payload,
                 size_t size) {
  ftl::UniqueFD fd(HANDLE_EINTR(creat(path.c_str(), 0666)));
  if (!fd.is_valid())
    return false;
  bool success = ftl::WriteFileDescriptor(fd.get(), interpreter_line.c_str(),
                                          interpreter_line.length());
  // page align the start of the payload for easy mapping in the content
  // handler.
  const intptr_t pagesize = getpagesize();
  char* padding = new char[pagesize];
  success =
      success && ftl::WriteFileDescriptor(fd.get(), padding,
                                          pagesize - interpreter_line.length());
  delete[] padding;
  return success && ftl::WriteFileDescriptor(fd.get(), payload, size);
}

int CreateBundle(const ftl::CommandLine& command_line) {
  if (command_line.HasOption(kHelp, nullptr)) {
    Usage();
    return 0;
  }

  std::string interpreter;
  std::string snapshot_key;
  std::string snapshot;
  std::string bundle;
  if (!command_line.positional_args().empty() ||
      !command_line.GetOptionValue(kInterpreter, &interpreter) ||
      !command_line.GetOptionValue(kSnapshotKey, &snapshot_key) ||
      !command_line.GetOptionValue(kSnapshot, &snapshot) ||
      !command_line.GetOptionValue(kBundle, &bundle)) {
    Usage();
    return 1;
  }

  std::vector<char> snapshot_blob;
  if (!files::ReadFileToVector(
          snapshot, reinterpret_cast<std::vector<uint8_t>*>(&snapshot_blob))) {
    std::cerr << "error: Failed to read snapshot from '" << snapshot << "'."
              << std::endl;
    return 1;
  }

  std::vector<char> bundle_blob = std::move(snapshot_blob);

  std::string interpreter_line = "#!fuchsia " + interpreter + "\n";
  if (!WriteBundle(bundle, interpreter_line, bundle_blob.data(),
                   bundle_blob.size())) {
    std::cerr << "error: Failed to write dartx bundle to '" << bundle << "'."
              << std::endl;
    return 1;
  }

  return 0;
}

}  // namespace
}  // namespace dart_snapshotter

int main(int argc, const char* argv[]) {
  return dart_snapshotter::CreateBundle(
      ftl::CommandLineFromArgcArgv(argc, argv));
}
