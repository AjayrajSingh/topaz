/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "fuchsia_font_manager.h"

#include <zx/vmar.h>

#include "flutter/fml/logging.h"
#include "lib/fsl/vmo/sized_vmo.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/weak_ptr.h"
#include "third_party/icu/source/common/unicode/uchar.h"
#include "third_party/skia/src/core/SkFontDescriptor.h"
#include "third_party/skia/src/ports/SkFontMgr_custom.h"
#include "txt/typeface_font_asset_provider.h"

namespace txt {

namespace {

constexpr char kDefaultFontFamily[] = "Roboto";

void UnmapMemory(const void* buffer, uint64_t size) {
  static_assert(sizeof(void*) == sizeof(uint64_t), "pointers aren't 64-bit");
  zx::vmar::root_self()->unmap(reinterpret_cast<uintptr_t>(buffer), size);
}

struct ReleaseSkDataContext {
  uint64_t buffer_size;
  int buffer_id;
  std::function<void()> release_proc;

  ReleaseSkDataContext(uint64_t buffer_size, int buffer_id,
                       const std::function<void()>& release_proc)
      : buffer_size(buffer_size),
        buffer_id(buffer_id),
        release_proc(release_proc) {}
};

void ReleaseSkData(const void* buffer, void* context) {
  auto skdata_context = reinterpret_cast<ReleaseSkDataContext*>(context);
  FXL_DCHECK(skdata_context);
  UnmapMemory(buffer, skdata_context->buffer_size);
  skdata_context->release_proc();
  delete skdata_context;
}

sk_sp<SkData> MakeSkDataFromBuffer(const fuchsia::mem::Buffer& data,
                                   int buffer_id,
                                   std::function<void()> release_proc) {
  if (!fsl::SizedVmo::IsSizeValid(data.vmo, data.size) ||
      data.size > std::numeric_limits<size_t>::max()) {
    return nullptr;
  }
  uint64_t size = data.size;
  uintptr_t buffer = 0;
  zx_status_t status = zx::vmar::root_self()->map(0, data.vmo, 0, size,
                                                  ZX_VM_PERM_READ, &buffer);
  if (status != ZX_OK)
    return nullptr;
  auto context = new ReleaseSkDataContext(size, buffer_id, release_proc);
  return SkData::MakeWithProc(reinterpret_cast<void*>(buffer), size,
                              ReleaseSkData, context);
}

fuchsia::fonts::Slant ToFontSlant(SkFontStyle::Slant slant) {
  switch (slant) {
    case SkFontStyle::kOblique_Slant:
      return fuchsia::fonts::Slant::OBLIQUE;
      break;
    case SkFontStyle::kItalic_Slant:
      return fuchsia::fonts::Slant::ITALIC;
      break;
    case SkFontStyle::kUpright_Slant:
    default:
      return fuchsia::fonts::Slant::UPRIGHT;
      break;
  }
}

fidl::VectorPtr<fidl::StringPtr> BuildLanguageList(const char* bcp47[],
                                                   int bcp47_count) {
  FXL_DCHECK(bcp47 != nullptr || bcp47_count == 0);
  auto languages = fidl::VectorPtr<fidl::StringPtr>::New(0);
  for (int i = 0; i < bcp47_count; i++) {
    languages.push_back(bcp47[i]);
  }
  return languages;
}

// SkTypeface with an "on deleted" callback.
class CachedTypeface : public SkTypeface_Stream {
 public:
  CachedTypeface(std::unique_ptr<SkFontData> font_data,
                 const SkFontStyle& style, bool is_fixed_pitch,
                 const SkString family_name,
                 const std::function<void()>& on_deleted)
      : SkTypeface_Stream(std::move(font_data), style, is_fixed_pitch,
                          /*sys_font=*/true, family_name),
        on_deleted_(on_deleted) {}

  ~CachedTypeface() override {
    if (on_deleted_)
      on_deleted_();
  }

 private:
  std::function<void()> on_deleted_;

  FXL_DISALLOW_COPY_AND_ASSIGN(CachedTypeface);
};

sk_sp<SkTypeface> CreateTypefaceFromSkStream(
    std::unique_ptr<SkStreamAsset> stream, const SkFontArguments& args,
    const std::function<void()>& on_deleted) {
  using Scanner = SkTypeface_FreeType::Scanner;
  Scanner scanner;
  bool is_fixed_pitch;
  SkFontStyle style;
  SkString name;
  Scanner::AxisDefinitions axis_definitions;
  if (!scanner.scanFont(stream.get(), args.getCollectionIndex(), &name, &style,
                        &is_fixed_pitch, &axis_definitions)) {
    return nullptr;
  }

  const SkFontArguments::VariationPosition position =
      args.getVariationDesignPosition();
  SkAutoSTMalloc<4, SkFixed> axis_values(axis_definitions.count());
  Scanner::computeAxisValues(axis_definitions, position, axis_values, name);

  auto font_data =
      std::make_unique<SkFontData>(std::move(stream), args.getCollectionIndex(),
                                   axis_values.get(), axis_definitions.count());
  return sk_make_sp<CachedTypeface>(std::move(font_data), style, is_fixed_pitch,
                                    name, on_deleted);
}

sk_sp<SkTypeface> CreateTypefaceFromSkData(
    sk_sp<SkData> data, int font_index,
    const std::function<void()>& on_deleted) {
  SkFontArguments args;
  args.setCollectionIndex(font_index);

  return CreateTypefaceFromSkStream(
      std::make_unique<SkMemoryStream>(std::move(data)),
      SkFontArguments().setCollectionIndex(font_index), on_deleted);
}

}  // anonymous namespace

class FuchsiaFontManager::TypefaceCache {
 public:
  TypefaceCache() : weak_factory_(this) {}

  // Get an SkTypeface with the given buffer id, font index, and buffer
  // data. Creates a new SkTypeface if one does not already exist.
  sk_sp<SkTypeface> GetOrCreateTypeface(
      int buffer_id, int font_index, const fuchsia::mem::Buffer& buffer) const;

 private:
  // Used to identify an SkTypeface in the cache.
  struct TypefaceId {
    int buffer_id;
    int font_index;

    // Needed by std::unordered_map.
    bool operator==(const TypefaceId& other) const {
      return (buffer_id == other.buffer_id && font_index == other.font_index);
    }

    // Used for debugging.
    friend std::ostream& operator<<(std::ostream& os, const TypefaceId& id) {
      return os << "TypfaceId: [buffer_id: " << id.buffer_id
                << ", font_index: " << id.font_index << "]";
    }
  };

  // Needed by std::unordered_map.
  struct TypefaceIdHash {
    std::size_t operator()(const TypefaceId& id) const {
      return std::hash<int>()(id.buffer_id) ^
             (std::hash<int>()(id.font_index) << 1);
    }
  };

  // Callback called when an SkTypeface with the given TypefaceId is deleted.
  void OnTypefaceDeleted(TypefaceId typeface_id) const;

  // Callback called when an SkData with the given buffer id is deleted.
  void OnSkDataDeleted(int buffer_id) const;

  // Try to get an SkData with the given buffer id from the cache. If an
  // SkData is not found, create it and add it to the cache.
  sk_sp<SkData> GetOrCreateSkData(int buffer_id,
                                  const fuchsia::mem::Buffer& buffer) const;

  // Create a new SkTypeface for the given TypefaceId and SkData and add it to
  // the cache.
  sk_sp<SkTypeface> CreateSkTypeface(TypefaceId id, sk_sp<SkData> buffer) const;

  mutable std::unordered_map<TypefaceId, SkTypeface*, TypefaceIdHash>
      typeface_cache_;
  mutable std::unordered_map<int, SkData*> buffer_cache_;

  // Must be last.
  mutable fxl::WeakPtrFactory<TypefaceCache> weak_factory_;

  FXL_DISALLOW_COPY_AND_ASSIGN(TypefaceCache);
};

void FuchsiaFontManager::TypefaceCache::OnSkDataDeleted(int buffer_id) const {
  bool was_found = buffer_cache_.erase(buffer_id) != 0;
  FML_DCHECK(was_found);
}

void FuchsiaFontManager::TypefaceCache::OnTypefaceDeleted(
    TypefaceId typeface_id) const {
  bool was_found = typeface_cache_.erase(typeface_id) != 0;
  FML_DCHECK(was_found);
}

sk_sp<SkData> FuchsiaFontManager::TypefaceCache::GetOrCreateSkData(
    int buffer_id, const fuchsia::mem::Buffer& buffer) const {
  auto iter = buffer_cache_.find(buffer_id);
  if (iter != buffer_cache_.end()) {
    return sk_ref_sp(iter->second);
  }
  auto weak_this = weak_factory_.GetWeakPtr();
  auto data = MakeSkDataFromBuffer(buffer, buffer_id, [weak_this, buffer_id]() {
    if (weak_this) {
      weak_this->OnSkDataDeleted(buffer_id);
    }
  });
  if (!data) {
    return nullptr;
  }
  buffer_cache_[buffer_id] = data.get();
  return data;
}

sk_sp<SkTypeface> FuchsiaFontManager::TypefaceCache::CreateSkTypeface(
    TypefaceId id, sk_sp<SkData> buffer) const {
  auto weak_this = weak_factory_.GetWeakPtr();
  auto result = CreateTypefaceFromSkData(std::move(buffer), id.font_index,
                                         [weak_this, id] {
                                           if (weak_this) {
                                             weak_this->OnTypefaceDeleted(id);
                                           }
                                         });
  typeface_cache_[id] = result.get();
  return result;
}

sk_sp<SkTypeface> FuchsiaFontManager::TypefaceCache::GetOrCreateTypeface(
    int buffer_id, int font_index, const fuchsia::mem::Buffer& buffer) const {
  auto id = TypefaceId{buffer_id, font_index};
  auto iter = typeface_cache_.find(id);
  if (iter != typeface_cache_.end()) {
    return sk_ref_sp(iter->second);
  }
  sk_sp<SkData> data = GetOrCreateSkData(buffer_id, buffer);
  if (!data) {
    return nullptr;
  }
  return CreateSkTypeface(id, std::move(data));
}

FuchsiaFontManager::FuchsiaFontManager(fuchsia::fonts::ProviderSyncPtr provider)
    : font_provider_(std::move(provider)),
      typeface_cache_(new FuchsiaFontManager::TypefaceCache()) {}

FuchsiaFontManager::~FuchsiaFontManager() = default;

int FuchsiaFontManager::onCountFamilies() const {
  FML_DCHECK(false);
  return 0;
}

void FuchsiaFontManager::onGetFamilyName(int index,
                                         SkString* familyName) const {
  FML_DCHECK(false);
}

SkFontStyleSet* FuchsiaFontManager::onCreateStyleSet(int index) const {
  FML_DCHECK(false);
  return nullptr;
}

SkFontStyleSet* FuchsiaFontManager::onMatchFamily(
    const char family_name[]) const {
  sk_sp<SkTypeface> typeface(onMatchFamilyStyle(family_name, SkFontStyle()));
  if (!typeface)
    return nullptr;

  sk_sp<txt::TypefaceFontStyleSet> font_style_set(
      sk_make_sp<txt::TypefaceFontStyleSet>());
  font_style_set->registerTypeface(typeface);

  return font_style_set.release();
}

SkTypeface* FuchsiaFontManager::onMatchFamilyStyle(
    const char familyName[], const SkFontStyle& style) const {
  sk_sp<SkTypeface> typeface = FetchTypeface(familyName, style, nullptr, 0, 0);
  return typeface.release();
}

SkTypeface* FuchsiaFontManager::onMatchFamilyStyleCharacter(
    const char familyName[], const SkFontStyle& style, const char* bcp47[],
    int bcp47_count, SkUnichar character) const {
  sk_sp<SkTypeface> typeface =
      FetchTypeface(kDefaultFontFamily, style, bcp47, bcp47_count, character);
  return typeface.release();
}

SkTypeface* FuchsiaFontManager::onMatchFaceStyle(const SkTypeface*,
                                                 const SkFontStyle&) const {
  FML_DCHECK(false);
  return nullptr;
}

sk_sp<SkTypeface> FuchsiaFontManager::onMakeFromData(sk_sp<SkData>,
                                                     int ttcIndex) const {
  FML_DCHECK(false);
  return nullptr;
}

sk_sp<SkTypeface> FuchsiaFontManager::onMakeFromStreamIndex(
    std::unique_ptr<SkStreamAsset>, int ttcIndex) const {
  FML_DCHECK(false);
  return nullptr;
}

sk_sp<SkTypeface> FuchsiaFontManager::onMakeFromStreamArgs(
    std::unique_ptr<SkStreamAsset>, const SkFontArguments&) const {
  FML_DCHECK(false);
  return nullptr;
}

sk_sp<SkTypeface> FuchsiaFontManager::onMakeFromFile(const char path[],
                                                     int ttcIndex) const {
  FML_DCHECK(false);
  return nullptr;
}

sk_sp<SkTypeface> FuchsiaFontManager::onLegacyMakeTypeface(
    const char familyName[], SkFontStyle) const {
  FML_DCHECK(false);
  return nullptr;
}

sk_sp<SkTypeface> FuchsiaFontManager::FetchTypeface(const char family_name[],
                                                    const SkFontStyle& style,
                                                    const char* bcp47[],
                                                    int bcp47_count,
                                                    SkUnichar character) const {
  fuchsia::fonts::Request request;
  request.family = family_name;
  request.weight = style.weight();
  request.width = style.width();
  request.slant = ToFontSlant(style.slant());
  request.language = BuildLanguageList(bcp47, bcp47_count);
  request.character = character;

  fuchsia::fonts::ResponsePtr response;
  int err = font_provider_->GetFont(std::move(request), &response);
  if (err != ZX_OK) {
    FML_DLOG(ERROR) << "Error fetching font from provider [err=" << err
                    << "]. Did you run Flutter in an environment that"
                    << " has a font manager? ";
    return nullptr;
  }

  return typeface_cache_->GetOrCreateTypeface(
      response->buffer_id, response->font_index, response->buffer);
}

}  // namespace txt
