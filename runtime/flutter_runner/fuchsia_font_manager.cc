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
#include "third_party/icu/source/common/unicode/uchar.h"
#include "txt/typeface_font_asset_provider.h"

namespace txt {

namespace {

void UnmapMemory(const void* buffer, void* context) {
  static_assert(sizeof(void*) == sizeof(uint64_t), "pointers aren't 64-bit");
  const uint64_t size = reinterpret_cast<uint64_t>(context);
  zx::vmar::root_self()->unmap(reinterpret_cast<uintptr_t>(buffer), size);
}

sk_sp<SkData> MakeSkDataFromBuffer(const fuchsia::mem::Buffer& data) {
  if (!fsl::SizedVmo::IsSizeValid(data.vmo, data.size) ||
      data.size > std::numeric_limits<size_t>::max()) {
    return nullptr;
  }
  uint64_t size = data.size;
  uintptr_t buffer = 0;
  zx_status_t status = zx::vmar::root_self()->map(
      0, data.vmo, 0, size, ZX_VM_PERM_READ, &buffer);
  if (status != ZX_OK)
    return nullptr;
  return SkData::MakeWithProc(reinterpret_cast<void*>(buffer), size,
                              UnmapMemory, reinterpret_cast<void*>(size));
}

fuchsia::fonts::Slant ToFontSlant(SkFontStyle::Slant slant) {
  return (slant == SkFontStyle::kItalic_Slant)
             ? fuchsia::fonts::Slant::ITALIC
             : fuchsia::fonts::Slant::UPRIGHT;
}

}  // anonymous namespace

FuchsiaFontManager::FuchsiaFontManager(
    fuchsia::fonts::ProviderSyncPtr provider)
    : font_provider_(std::move(provider)) {}

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
    const char family_name[], const SkFontStyle& style) const {
  fuchsia::fonts::Request request;
  request.family = family_name;
  request.weight = style.weight();
  request.width = style.width();
  request.slant = ToFontSlant(style.slant());

  fuchsia::fonts::ResponsePtr response;
  if (font_provider_->GetFont(std::move(request), &response) != ZX_OK) {
    FML_DLOG(ERROR) << "Unable to contact the font provider. Did you run "
                       "Flutter in an environment that has a font manager?";
    return nullptr;
  }

  sk_sp<SkData> data = MakeSkDataFromBuffer(response->buffer);
  if (!data)
    return nullptr;

  sk_sp<SkTypeface> typeface =
      SkFontMgr::RefDefault()->makeFromData(std::move(data));

  return typeface.release();
}

SkTypeface* FuchsiaFontManager::onMatchFamilyStyleCharacter(
    const char familyName[], const SkFontStyle& style, const char* bcp47[],
    int bcp47Count, SkUnichar character) const {
  if (u_hasBinaryProperty(character, UCHAR_EMOJI)) {
    return onMatchFamilyStyle("Noto Color Emoji", style);
  } else if (character == 8242 || character == 8243) {
    // GoogleSans does not have Prime and Double Prime symbols.
    // Fallback to Roboto.
    // http://www.codetable.net/decimal/8242
    return onMatchFamilyStyle("Roboto", style);
  }
  return nullptr;
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

}  // namespace txt
