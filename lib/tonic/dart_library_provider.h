// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_DART_LIBRARY_PROVIDER_H_
#define LIB_TONIC_DART_LIBRARY_PROVIDER_H_

#include <functional>
#include <string>

#include "dart/runtime/include/dart_api.h"
#include "mojo/public/cpp/system/data_pipe.h"

namespace tonic {

typedef std::function<void(mojo::ScopedDataPipeConsumerHandle)>
    DataPipeConsumerCallback;

class DartLibraryProvider {
 public:
  virtual void GetLibraryAsStream(const std::string& name,
                                  DataPipeConsumerCallback callback) = 0;

  virtual Dart_Handle CanonicalizeURL(Dart_Handle library, Dart_Handle url) = 0;

  virtual ~DartLibraryProvider();
};

}  // namespace tonic

#endif  // LIB_TONIC_DART_LIBRARY_PROVIDER_H_
