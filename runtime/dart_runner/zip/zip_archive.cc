// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/zip/zip_archive.h"

#include <stdio.h>

#include <algorithm>
#include <utility>

#include "lib/ftl/logging.h"
#include "third_party/zlib/contrib/minizip/unzip.h"

namespace dart_content_handler {
namespace {

struct FileStream {
  const char* begin = nullptr;
  size_t size = 0u;
  size_t offset = 0u;
};

void* OpenFile(void* opaque, const char* filename, int mode) {
  ZipArchive* archive = static_cast<ZipArchive*>(opaque);
  FileStream* fstream = new FileStream();
  fstream->begin = archive->buffer().data();
  fstream->size = archive->buffer().size();
  return fstream;
}

unsigned long ReadFile(void* opaque,
                       void* stream,
                       void* buffer,
                       unsigned long size) {
  FileStream* fstream = static_cast<FileStream*>(stream);
  unsigned long bytes_read = std::min(size, fstream->size - fstream->offset);
  memcpy(buffer, fstream->begin + fstream->offset, bytes_read);
  fstream->offset += bytes_read;
  return bytes_read;
}

unsigned long WriteFile(void* opaque,
                        void* stream,
                        const void* buffer,
                        unsigned long size) {
  FTL_CHECK(false) << "Not implemented.";
  return -1;
}

long TellFile(void* opaque, void* stream) {
  FileStream* fstream = static_cast<FileStream*>(stream);
  return fstream->offset;
}

long SeekFile(void* opaque, void* stream, unsigned long offset, int origin) {
  FileStream* fstream = static_cast<FileStream*>(stream);
  switch (origin) {
    case SEEK_SET: {
      if (offset > fstream->size)
        break;
      fstream->offset = offset;
      return 0;
    }
    case SEEK_CUR: {
      size_t target = fstream->offset + offset;
      if (target > fstream->size)
        break;
      fstream->offset = target;
      return 0;
    }
    case SEEK_END: {
      if (offset > fstream->size)
        break;
      fstream->offset = fstream->size - offset;
      return 0;
    }
    default:
      break;
  }
  return -1;
}

int CloseFile(void* opaque, void* stream) {
  FileStream* fstream = static_cast<FileStream*>(stream);
  delete fstream;
  return 0;
}

int ErrorFile(void* opaque, void* stream) {
  return 0;
}

constexpr zlib_filefunc_def kZLibFileFunctions = {
    &OpenFile, &ReadFile,  &WriteFile, &TellFile,
    &SeekFile, &CloseFile, &ErrorFile, nullptr,
};

}  // namespace

ZipArchive::ZipArchive(std::vector<char> buffer) : buffer_(std::move(buffer)) {
  zlib_filefunc_def file_functions = kZLibFileFunctions;
  file_functions.opaque = this;
  archive_.reset(unzOpen2(nullptr, &file_functions));
}

ZipArchive::~ZipArchive() {}

std::vector<char> ZipArchive::Extract(const std::string& path) {
  std::vector<char> buffer;

  int result = unzLocateFile(archive_.get(), path.c_str(), 0);
  if (result != UNZ_OK) {
    FTL_LOG(WARNING) << "Unable to locate " << path << " in archive.";
    return buffer;
  }

  result = unzOpenCurrentFile(archive_.get());
  if (result != UNZ_OK) {
    FTL_LOG(WARNING) << "unzOpenCurrentFile failed, error=" << result;
    return buffer;
  }

  unz_file_info file_info;
  result = unzGetCurrentFileInfo(archive_.get(), &file_info, nullptr, 0,
                                 nullptr, 0, nullptr, 0);
  if (result != UNZ_OK) {
    FTL_LOG(WARNING) << "unzGetCurrentFileInfo failed, error=" << result;
    return buffer;
  }

  buffer.resize(file_info.uncompressed_size);

  result = unzReadCurrentFile(archive_.get(), buffer.data(), buffer.size());
  if (result < 0 || static_cast<size_t>(result) != buffer.size()) {
    FTL_LOG(WARNING) << "Unzip failed, error=" << result;
    buffer.clear();
    return buffer;
  }

  return buffer;
}

}  // namespace dart_content_handler
