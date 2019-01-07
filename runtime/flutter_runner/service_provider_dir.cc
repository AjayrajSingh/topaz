// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/flutter_runner/service_provider_dir.h"

#include <lib/async/default.h>
#include <lib/fdio/util.h>
#include <zircon/status.h>

namespace flutter {

ServiceProviderDir::ServiceProviderDir()
    : root_(fbl::AdoptRef(new fs::PseudoDir)), weak_factory_(this) {}

ServiceProviderDir::~ServiceProviderDir() {}

void ServiceProviderDir::set_fallback(
    fidl::InterfaceHandle<fuchsia::io::Directory> fallback_dir) {
  fallback_dir_ = fallback_dir.TakeChannel();
}

void ServiceProviderDir::AddService(const std::string& service_name,
                                    fbl::RefPtr<fs::Service> service) {
  root_->AddEntry(service_name, std::move(service));
}

zx_status_t ServiceProviderDir::Getattr(vnattr_t* a) {
  return root_->Getattr(a);
}

zx_status_t ServiceProviderDir::Readdir(fs::vdircookie_t* cookie, void* dirents,
                                        size_t len, size_t* out_actual) {
  // TODO(anmittal): enumerate fallback_dir_ in future once we have simple
  // implementation of fuchsia.io.Directory.
  return root_->Readdir(cookie, dirents, len, out_actual);
}

zx_status_t ServiceProviderDir::Lookup(fbl::RefPtr<fs::Vnode>* out,
                                       fbl::StringPiece name) {
  zx_status_t status = root_->Lookup(out, name);
  if (status == ZX_OK) {
    return status;
  }
  if (fallback_dir_) {
    *out = fbl::AdoptRef(new fs::Service(
        [name = std::string(name.data(), name.length()),
         ptr = weak_factory_.GetWeakPtr()](zx::channel request) {
          if (ptr) {
            fdio_service_connect_at(ptr->fallback_dir_.get(), name.c_str(),
                                    request.release());
            return ZX_OK;
          }
          return ZX_ERR_NOT_FOUND;
        }));
  } else {
    return ZX_ERR_NOT_FOUND;
  }
  return ZX_OK;
}

}  // namespace flutter
