/*
 * Copyright 2016 The Fuchsia Authors. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <assert.h>
#include <dirent.h>
#include <fcntl.h>
#include <math.h>
#include <stdlib.h>

#include <algorithm>
#include <chrono>
#include <iostream>
#include <map>
#include <vector>

#include <lib/async-loop/cpp/loop.h>
#include <lib/fdio/namespace.h>
#include <lib/fdio/util.h>
#include <lib/fxl/command_line.h>
#include <lib/fxl/files/unique_fd.h>
#include <lib/fxl/logging.h>

#include "topaz/runtime/web_view/web_view_provider.h"

using std::cerr;
using std::cout;
using std::endl;

namespace {
constexpr char kDefaultUrl[] = "http://www.google.com/";
}  // namespace

int main(int argc, const char** argv) {
  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  std::vector<std::string> urls = command_line.positional_args();
  std::string url = kDefaultUrl;
  if (!urls.empty()) {
    url = urls.front();
  }

  fxl::UniqueFD fd(open("/pkg/data/webkit", O_RDONLY | O_DIRECTORY));
  if (fd.is_valid()) {
    fdio_ns_t* ns;
    zx_status_t st = fdio_ns_get_installed(&ns);
    if (st != ZX_OK) {
      fprintf(stderr, "Could not get installed namespace: %d", st);
      return 1;
    }

    st = fdio_ns_bind_fd(ns, "/system/data/webkit", fd.get());
    if (st != ZX_OK) {
      fprintf(stderr,
              "Could not install webkit data entry to /system/data/webkit: %d",
              st);
      return 1;
    }
  }

  async::Loop loop(&kAsyncLoopConfigAttachToThread);

  WebViewProvider view_provider(&loop, url);

  loop.Run();

  return 0;
}
