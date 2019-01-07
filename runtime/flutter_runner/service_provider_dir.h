// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_SERVICE_PROVIDER_DIR_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_SERVICE_PROVIDER_DIR_H_

#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

#include <fs/pseudo-dir.h>
#include <fs/service.h>
#include <fs/synchronous-vfs.h>
#include <fuchsia/io/cpp/fidl.h>
#include <fuchsia/sys/cpp/fidl.h>

#include "lib/fidl/cpp/binding_set.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/weak_ptr.h"

namespace flutter {

// A directory-like object which dynamically creates Service vnodes
// for any file lookup. It also exposes service provider interface.
//
// It supports enumeration for only first level of services.
class ServiceProviderDir : public fs::Vnode {
 public:
  ServiceProviderDir();
  ~ServiceProviderDir() override;

  void set_fallback(fidl::InterfaceHandle<fuchsia::io::Directory> fallback_dir);

  void AddService(const std::string& service_name,
                  fbl::RefPtr<fs::Service> service);

  //
  // Overridden from |fs::Vnode|:
  //

  zx_status_t Lookup(fbl::RefPtr<fs::Vnode>* out, fbl::StringPiece name) final;

  zx_status_t Getattr(vnattr_t* a) final;

  zx_status_t Readdir(fs::vdircookie_t* cookie, void* dirents, size_t len,
                      size_t* out_actual) final;

 private:
  // |root_| has all services offered by this provider (including those
  // inherited from the parent, if any).
  fbl::RefPtr<fs::PseudoDir> root_;
  zx::channel fallback_dir_;
  fxl::WeakPtrFactory<ServiceProviderDir> weak_factory_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ServiceProviderDir);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_SERVICE_PROVIDER_DIR_H_
