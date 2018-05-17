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

#ifndef TXT_FUCHSIA_FONT_MANAGER_H_
#define TXT_FUCHSIA_FONT_MANAGER_H_

#include <fonts/cpp/fidl.h>
#include <memory>
#include "lib/fxl/macros.h"
#include "third_party/skia/include/core/SkStream.h"
#include "third_party/skia/include/core/SkTypeface.h"
#include "third_party/skia/include/ports/SkFontMgr.h"

namespace txt {

class FuchsiaFontManager final : public SkFontMgr {
 public:
  FuchsiaFontManager(fonts::FontProviderSyncPtr provider);

  ~FuchsiaFontManager() override;

 protected:
  // |SkFontMgr|
  int onCountFamilies() const override;

  // |SkFontMgr|
  void onGetFamilyName(int index, SkString* familyName) const override;

  // |SkFontMgr|
  SkFontStyleSet* onMatchFamily(const char familyName[]) const override;

  // |SkFontMgr|
  SkFontStyleSet* onCreateStyleSet(int index) const override;

  // |SkFontMgr|
  SkTypeface* onMatchFamilyStyle(const char familyName[],
                                 const SkFontStyle&) const override;

  // |SkFontMgr|
  SkTypeface* onMatchFamilyStyleCharacter(const char familyName[],
                                          const SkFontStyle&,
                                          const char* bcp47[],
                                          int bcp47Count,
                                          SkUnichar character) const override;
  // |SkFontMgr|
  SkTypeface* onMatchFaceStyle(const SkTypeface*,
                               const SkFontStyle&) const override;

  // |SkFontMgr|
  sk_sp<SkTypeface> onMakeFromData(sk_sp<SkData>, int ttcIndex) const override;

  // |SkFontMgr|
  sk_sp<SkTypeface> onMakeFromStreamIndex(std::unique_ptr<SkStreamAsset>,
                                          int ttcIndex) const override;

  // |SkFontMgr|
  sk_sp<SkTypeface> onMakeFromStreamArgs(std::unique_ptr<SkStreamAsset>,
                                         const SkFontArguments&) const override;

  // |SkFontMgr|
  sk_sp<SkTypeface> onMakeFromFile(const char path[],
                                   int ttcIndex) const override;

  // |SkFontMgr|
  sk_sp<SkTypeface> onLegacyMakeTypeface(const char familyName[],
                                         SkFontStyle) const override;

  FXL_DISALLOW_COPY_AND_ASSIGN(FuchsiaFontManager);

 private:
  mutable fonts::FontProviderSyncPtr font_provider_;
};

}  // namespace txt

#endif  // TXT_FUCHSIA_FONT_MANAGER_H_
