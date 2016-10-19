// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/ledger/api/ledger.mojom.h"
#include "apps/maxwell/document_store/interfaces/document_store.mojom.h"

namespace document_store {

namespace internal {
// Translates the ledger::Status to the document_store::Status equivalent.
Status LedgerStatusToStatus(ledger::Status ledger_status) {
  switch (ledger_status) {
    case ledger::Status::OK:
      return Status::OK;
    case ledger::Status::PAGE_NOT_FOUND:
      return Status::PAGE_NOT_FOUND;
    default:
      return Status::UNKNOWN_ERROR;
  }
}
}  // namespace internal

// TODO(azani): Delete when done debugging.
std::string b2h(const mojo::Array<uint8_t>& arr) {
  std::stringstream ss;
  for (size_t i = 0; i < arr.size(); ++i) {
    ss << std::hex << static_cast<int>(arr[i]);
  }
  return ss.str();
}

std::string b2s(const mojo::Array<uint8_t>& arr) {
  std::stringstream ss;
  for (size_t i = 0; i < arr.size(); ++i) {
    if (arr[i] == '\0') {
      ss << "\\0";
    } else {
      ss << static_cast<char>(arr[i]);
    }
  }
  return ss.str();
}

}  // namespace document_store
