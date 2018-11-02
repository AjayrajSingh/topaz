// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "fuchsia_font_manager.h"

#include <fuchsia/fonts/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>
#include <lib/component/cpp/startup_context.h>
#include <lib/fidl/cpp/binding.h>
#include <lib/fxl/files/file.h>

#include "gtest/gtest.h"
#include "third_party/skia/include/core/SkFontMgr.h"
#include "third_party/skia/include/core/SkTypeface.h"

namespace txt {

namespace {

constexpr zx_rights_t kFontDataRights =
    ZX_RIGHTS_BASIC | ZX_RIGHT_READ | ZX_RIGHT_MAP;

// Guaranteed to be an unassigned unicode codepoint.
constexpr SkUnichar kUnicodeNonCharacter = 0x10FFFF;

fuchsia::mem::Buffer LoadFont(std::string file_path) {
  std::string file_content;
  FXL_CHECK(files::ReadFileToString(file_path, &file_content));
  fuchsia::mem::Buffer buffer;
  zx_status_t status = zx::vmo::create(file_content.size(), 0, &buffer.vmo);
  FXL_CHECK(status == ZX_OK);
  status = buffer.vmo.write(file_content.data(), 0, file_content.size());
  FXL_CHECK(status == ZX_OK);
  buffer.size = file_content.size();
  return buffer;
}

// Fake fuchsia::fonts::Provider implementation.
// TODO(wleshner): Use the real font provider instead of this fake.
class FakeFontProvider : public fuchsia::fonts::Provider {
 public:
  void GetFont(fuchsia::fonts::Request request,
               GetFontCallback callback) override {
    if (request.character == kUnicodeNonCharacter) {
      // Special "unknown character" case.
      callback(nullptr);
      return;
    }

    // This just has to be unique for the font data returned so that the font
    // manager will cache the fonts properly.
    int buffer_id;

    fuchsia::mem::Buffer* font_buffer = nullptr;
    if (*request.family == "Roboto") {
      AssureFontData(&roboto_,
                     "/pkgfs/packages/fonts/0/data/fonts/Roboto-Regular.ttf");
      font_buffer = &roboto_;
      buffer_id = 1;
    } else if (*request.family == "RobotoSlab") {
      AssureFontData(
          &roboto_slab_,
          "/pkgfs/packages/fonts/0/data/fonts/RobotoSlab-Regular.ttf");
      font_buffer = &roboto_slab_;
      buffer_id = 2;
    }

    if (!font_buffer) {
      callback(nullptr);
      return;
    }

    auto response = fuchsia::fonts::Response::New();
    EXPECT_EQ(
        font_buffer->vmo.duplicate(kFontDataRights, &(response->buffer.vmo)),
        ZX_OK);
    response->buffer.size = font_buffer->size;
    response->buffer_id = buffer_id;
    // Since there is only one font in our "collection", font_index is always 0.
    response->font_index = 0;
    callback(std::move(response));
  }

  void GetFamilyInfo(::fidl::StringPtr family,
                     GetFamilyInfoCallback callback) override {
    if (family != "Roboto") {
      callback(nullptr);
      return;
    }

    auto response = fuchsia::fonts::FamilyInfo::New();
    response->name = "Roboto";
    response->styles = ::fidl::VectorPtr<fuchsia::fonts::Style>::New(0);
    response->styles.push_back(
        CreateStyle(400, 5, fuchsia::fonts::Slant::UPRIGHT));
    callback(std::move(response));
  }

 private:
  void AssureFontData(fuchsia::mem::Buffer* buffer, std::string file_path) {
    if (buffer->size == 0) {
      *buffer = LoadFont(file_path);
    }
  }

  static fuchsia::fonts::Style CreateStyle(int weight, int width,
                                           fuchsia::fonts::Slant slant) {
    fuchsia::fonts::Style style;
    style.weight = weight;
    style.width = width;
    style.slant = slant;
    return style;
  }

  fuchsia::mem::Buffer roboto_;
  fuchsia::mem::Buffer roboto_slab_;
};

class FuchsiaFontManagerTest : public testing::Test {
 public:
  FuchsiaFontManagerTest()
      : loop_(&kAsyncLoopConfigNoAttachToThread), binding_(&font_provider_) {
    loop_.StartThread();
    fuchsia::fonts::ProviderSyncPtr ptr;
    ptr.Bind(binding_.NewBinding(loop_.dispatcher()));
    font_manager_ = sk_make_sp<FuchsiaFontManager>(std::move(ptr));
  }

 protected:
  async::Loop loop_;
  sk_sp<SkFontMgr> font_manager_;
  FakeFontProvider font_provider_;
  fidl::Binding<fuchsia::fonts::Provider> binding_;
};

// Verify that a typeface is returned for a found character.
TEST_F(FuchsiaFontManagerTest, ValidResponseWhenCharacterFound) {
  sk_sp<SkTypeface> sans(font_manager_->matchFamilyStyleCharacter(
      "", SkFontStyle(), nullptr, 0, '&'));
  EXPECT_TRUE(sans.get() != nullptr);
}

// Verify that a codepoint that doesn't map to a character correctly returns
// an empty typeface.
TEST_F(FuchsiaFontManagerTest, EmptyResponseWhenCharacterNotFound) {
  sk_sp<SkTypeface> sans(font_manager_->matchFamilyStyleCharacter(
      "", SkFontStyle(), nullptr, 0, kUnicodeNonCharacter));
  EXPECT_TRUE(sans.get() == nullptr);
}

// Verify that SkTypeface objects are cached.
TEST_F(FuchsiaFontManagerTest, Caching) {
  sk_sp<SkTypeface> sans(
      font_manager_->matchFamilyStyle("Roboto", SkFontStyle()));
  sk_sp<SkTypeface> sans2(
      font_manager_->matchFamilyStyle("Roboto", SkFontStyle()));

  // Expect that the same SkTypeface is returned for both requests.
  EXPECT_EQ(sans.get(), sans2.get());

  // Request serif and verify that a different SkTypeface is returned.
  sk_sp<SkTypeface> serif(
      font_manager_->matchFamilyStyle("RobotoSlab", SkFontStyle()));
  EXPECT_NE(sans.get(), serif.get());
}

// Verify that SkTypeface can outlive the manager.
TEST_F(FuchsiaFontManagerTest, TypefaceOutlivesManager) {
  sk_sp<SkTypeface> sans(
      font_manager_->matchFamilyStyle("Roboto", SkFontStyle()));
  font_manager_.reset();
  EXPECT_TRUE(sans.get() != nullptr);
}

// Verify that we can query a font after releasing a previous instance.
TEST_F(FuchsiaFontManagerTest, ReleaseThenCreateAgain) {
  sk_sp<SkTypeface> serif(
      font_manager_->matchFamilyStyle("RobotoSlab", SkFontStyle()));
  EXPECT_TRUE(serif != nullptr);
  serif.reset();

  sk_sp<SkTypeface> serif2(
      font_manager_->matchFamilyStyle("RobotoSlab", SkFontStyle()));
  EXPECT_TRUE(serif2 != nullptr);
}

// Verify that unknown font families are handled correctly.
TEST_F(FuchsiaFontManagerTest, MatchUnknownFamily) {
  SkFontStyleSet* style_set = font_manager_->matchFamily("unknown");
  EXPECT_TRUE(style_set == nullptr || style_set->count() == 0);
}

// Verify that a style set is returned for a known family.
TEST_F(FuchsiaFontManagerTest, MatchKnownFamily) {
  SkFontStyleSet* style_set = font_manager_->matchFamily("Roboto");
  EXPECT_GT(style_set->count(), 0);
}

// Verify getting an SkFontStyle from a matched family.
TEST_F(FuchsiaFontManagerTest, FontFamilyGetStyle) {
  SkFontStyleSet* style_set = font_manager_->matchFamily("Roboto");
  SkFontStyle style;
  style_set->getStyle(0, &style, nullptr);
  EXPECT_EQ(style.weight(), 400);
  EXPECT_EQ(style.width(), 5);
  EXPECT_EQ(style.slant(), SkFontStyle::kUpright_Slant);
}

// Verify creating a typeface from a matched family.
TEST_F(FuchsiaFontManagerTest, FontFamilyCreateTypeface) {
  SkFontStyleSet* style_set = font_manager_->matchFamily("Roboto");
  SkTypeface* typeface = style_set->createTypeface(0);
  EXPECT_TRUE(typeface != nullptr);
  SkFontStyle style = typeface->fontStyle();
  EXPECT_EQ(style.weight(), 400);
  EXPECT_EQ(style.width(), 5);
  EXPECT_EQ(style.slant(), SkFontStyle::kUpright_Slant);
}

}  // namespace

}  // namespace txt
