// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/flutter_runner/platform_view.h"

#include <gtest/gtest.h>
#include <lib/async-loop/cpp/loop.h>
#include <lib/fidl/cpp/binding_set.h>
#include <lib/fidl/cpp/interface_request.h>
#include <lib/gtest/real_loop_fixture.h>
#include <lib/sys/cpp/testing/service_directory_provider.h>

#include <memory>
#include <vector>

#include "flutter/lib/ui/window/platform_message.h"
#include "flutter/lib/ui/window/window.h"
#include "flutter_runner_fakes.h"
#include "fuchsia/ui/views/cpp/fidl.h"
#include "googletest/googletest/include/gtest/gtest.h"

namespace flutter_runner_test::flutter_runner_a11y_test {
using PlatformViewTests = gtest::RealLoopFixture;

class MockPlatformViewDelegate : public flutter::PlatformView::Delegate {
 public:
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewCreated(std::unique_ptr<flutter::Surface> surface) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewDestroyed() {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewSetNextFrameCallback(fml::closure closure) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewSetViewportMetrics(
      const flutter::ViewportMetrics& metrics) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewDispatchPlatformMessage(
      fml::RefPtr<flutter::PlatformMessage> message) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewDispatchPointerDataPacket(
      std::unique_ptr<flutter::PointerDataPacket> packet) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewDispatchSemanticsAction(int32_t id,
                                             flutter::SemanticsAction action,
                                             std::vector<uint8_t> args) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewSetSemanticsEnabled(bool enabled) {
    semantics_enabled_ = enabled;
  }
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewSetAccessibilityFeatures(int32_t flags) {
    semantics_features_ = flags;
  }
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewRegisterTexture(
      std::shared_ptr<flutter::Texture> texture) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewUnregisterTexture(int64_t texture_id) {}
  // |flutter::PlatformView::Delegate|
  void OnPlatformViewMarkTextureFrameAvailable(int64_t texture_id) {}

  bool SemanticsEnabled() const { return semantics_enabled_; }
  int32_t SemanticsFeatures() const { return semantics_features_; }

 private:
  bool semantics_enabled_ = false;
  int32_t semantics_features_ = 0;
};
TEST_F(PlatformViewTests, SurvivesWhenSettingsManagerNotAvailable) {
  sys::testing::ServiceDirectoryProvider services_provider(dispatcher());
  MockPlatformViewDelegate delegate;
  zx::eventpair a, b;
  zx::eventpair::create(/* flags */ 0u, &a, &b);
  auto view_ref = fuchsia::ui::views::ViewRef({
      .reference = std::move(a),
  });
  auto view_ref_control = fuchsia::ui::views::ViewRefControl({
      .reference = std::move(b),
  });
  flutter::TaskRunners task_runners =
      flutter::TaskRunners("test_runners", nullptr, nullptr, nullptr, nullptr);

  EXPECT_FALSE(delegate.SemanticsEnabled());
  EXPECT_EQ(delegate.SemanticsFeatures(), 0);

  auto platform_view = flutter_runner::PlatformView(
      delegate,                               // delegate
      "test_platform_view",                   // label
      std::move(view_ref_control),            // view_ref_control
      std::move(view_ref),                    // view_ref
      std::move(task_runners),                // task_runners
      services_provider.service_directory(),  // runner_services
      nullptr,  // parent_environment_service_provider_handle
      nullptr,  // session_listener_request
      nullptr,  // on_session_listener_error_callback
      nullptr,  // session_metrics_did_change_callback
      nullptr,  // session_size_change_hint_callback
      nullptr,  // on_enable_wireframe_callback,
      0u        // vsync_event_handle
  );

  RunLoopUntilIdle();

  EXPECT_FALSE(delegate.SemanticsEnabled());
  EXPECT_EQ(delegate.SemanticsFeatures(), 0);
}

TEST_F(PlatformViewTests, RegistersWatcherAndEnablesSemantics) {
  fuchsia::accessibility::Settings settings;
  settings.set_screen_reader_enabled(true);
  settings.set_color_inversion_enabled(true);
  MockAccessibilitySettingsManager settings_manager =
      MockAccessibilitySettingsManager(std::move(settings));
  MockSemanticsManager semantics_manager = MockSemanticsManager();
  sys::testing::ServiceDirectoryProvider services_provider(dispatcher());
  services_provider.AddService(settings_manager.GetHandler(dispatcher()),
                               AccessibilitySettingsManager::Name_);
  services_provider.AddService(semantics_manager.GetHandler(dispatcher()),
                               SemanticsManager::Name_);

  MockPlatformViewDelegate delegate;
  zx::eventpair a, b;
  zx::eventpair::create(/* flags */ 0u, &a, &b);
  auto view_ref = fuchsia::ui::views::ViewRef({
      .reference = std::move(a),
  });
  auto view_ref_control = fuchsia::ui::views::ViewRefControl({
      .reference = std::move(b),
  });
  flutter::TaskRunners task_runners =
      flutter::TaskRunners("test_runners", nullptr, nullptr, nullptr, nullptr);

  EXPECT_FALSE(delegate.SemanticsEnabled());
  EXPECT_EQ(delegate.SemanticsFeatures(), 0);

  auto platform_view = flutter_runner::PlatformView(
      delegate,                               // delegate
      "test_platform_view",                   // label
      std::move(view_ref_control),            // view_ref_control
      std::move(view_ref),                    // view_ref
      std::move(task_runners),                // task_runners
      services_provider.service_directory(),  // runner_services
      nullptr,  // parent_environment_service_provider_handle
      nullptr,  // session_listener_request
      nullptr,  // on_session_listener_error_callback
      nullptr,  // session_metrics_did_change_callback
      nullptr,  // session_size_change_hint_callback
      nullptr,  // wireframe_enabled_callback
      0u        // vsync_event_handle
  );

  RunLoopUntilIdle();

  EXPECT_TRUE(settings_manager.WatchCalled());
  EXPECT_TRUE(delegate.SemanticsEnabled());
  EXPECT_EQ(
      delegate.SemanticsFeatures(),
      static_cast<int32_t>(flutter::AccessibilityFeatureFlag::kInvertColors) |
          static_cast<int32_t>(
              flutter::AccessibilityFeatureFlag::kAccessibleNavigation));
}

TEST_F(PlatformViewTests, ChangesSettings) {
  fuchsia::accessibility::Settings settings;
  settings.set_screen_reader_enabled(true);
  settings.set_color_inversion_enabled(true);
  MockAccessibilitySettingsManager settings_manager =
      MockAccessibilitySettingsManager(std::move(settings));
  MockSemanticsManager semantics_manager = MockSemanticsManager();
  sys::testing::ServiceDirectoryProvider services_provider(dispatcher());
  services_provider.AddService(settings_manager.GetHandler(dispatcher()),
                               AccessibilitySettingsManager::Name_);
  services_provider.AddService(semantics_manager.GetHandler(dispatcher()),
                               SemanticsManager::Name_);

  MockPlatformViewDelegate delegate;
  zx::eventpair a, b;
  zx::eventpair::create(/* flags */ 0u, &a, &b);
  auto view_ref = fuchsia::ui::views::ViewRef({
      .reference = std::move(a),
  });
  auto view_ref_control = fuchsia::ui::views::ViewRefControl({
      .reference = std::move(b),
  });
  flutter::TaskRunners task_runners =
      flutter::TaskRunners("test_runners", nullptr, nullptr, nullptr, nullptr);

  EXPECT_FALSE(delegate.SemanticsEnabled());
  EXPECT_EQ(delegate.SemanticsFeatures(), 0);

  auto platform_view = flutter_runner::PlatformView(
      delegate,                               // delegate
      "test_platform_view",                   // label
      std::move(view_ref_control),            // view_ref_control
      std::move(view_ref),                    // view_ref
      std::move(task_runners),                // task_runners
      services_provider.service_directory(),  // runner_services
      nullptr,  // parent_environment_service_provider_handle
      nullptr,  // session_listener_request
      nullptr,  // on_session_listener_error_callback
      nullptr,  // session_metrics_did_change_callback
      nullptr,  // session_size_change_hint_callback
      nullptr,  // wireframe_enabled_callback
      0u        // vsync_event_handle
  );

  RunLoopUntilIdle();

  EXPECT_TRUE(settings_manager.WatchCalled());
  EXPECT_TRUE(delegate.SemanticsEnabled());
  EXPECT_EQ(
      delegate.SemanticsFeatures(),
      static_cast<int32_t>(flutter::AccessibilityFeatureFlag::kInvertColors) |
          static_cast<int32_t>(
              flutter::AccessibilityFeatureFlag::kAccessibleNavigation));

  fuchsia::accessibility::Settings screen_no_color_inversion;
  screen_no_color_inversion.set_screen_reader_enabled(true);
  screen_no_color_inversion.set_color_inversion_enabled(false);

  platform_view.OnSettingsChange(std::move(screen_no_color_inversion));
  EXPECT_TRUE(delegate.SemanticsEnabled());
  EXPECT_EQ(delegate.SemanticsFeatures(),
            static_cast<int32_t>(
                flutter::AccessibilityFeatureFlag::kAccessibleNavigation));

  fuchsia::accessibility::Settings disabled_settings;
  disabled_settings.set_screen_reader_enabled(false);
  disabled_settings.set_color_inversion_enabled(false);

  platform_view.OnSettingsChange(std::move(disabled_settings));
  EXPECT_FALSE(delegate.SemanticsEnabled());
  EXPECT_EQ(delegate.SemanticsFeatures(), 0);
}

TEST_F(PlatformViewTests, RegistersWatcherAndSetsFeaturesWhenNoScreenReader) {
  fuchsia::accessibility::Settings settings;
  settings.set_color_inversion_enabled(true);
  MockAccessibilitySettingsManager settings_manager =
      MockAccessibilitySettingsManager(std::move(settings));
  MockSemanticsManager semantics_manager = MockSemanticsManager();
  sys::testing::ServiceDirectoryProvider services_provider(dispatcher());
  services_provider.AddService(settings_manager.GetHandler(dispatcher()),
                               AccessibilitySettingsManager::Name_);
  services_provider.AddService(semantics_manager.GetHandler(dispatcher()),
                               SemanticsManager::Name_);

  MockPlatformViewDelegate delegate;
  zx::eventpair a, b;
  zx::eventpair::create(/* flags */ 0u, &a, &b);
  auto view_ref = fuchsia::ui::views::ViewRef({
      .reference = std::move(a),
  });
  auto view_ref_control = fuchsia::ui::views::ViewRefControl({
      .reference = std::move(b),
  });
  flutter::TaskRunners task_runners =
      flutter::TaskRunners("test_runners", nullptr, nullptr, nullptr, nullptr);

  EXPECT_FALSE(delegate.SemanticsEnabled());
  EXPECT_EQ(delegate.SemanticsFeatures(), 0);

  auto platform_view = flutter_runner::PlatformView(
      delegate,                               // delegate
      "test_platform_view",                   // label
      std::move(view_ref_control),            // view_ref_control
      std::move(view_ref),                    // view_ref
      std::move(task_runners),                // task_runners
      services_provider.service_directory(),  // runner_services
      nullptr,  // parent_environment_service_provider_handle
      nullptr,  // session_listener_request
      nullptr,  // on_session_listener_error_callback
      nullptr,  // session_metrics_did_change_callback
      nullptr,  // session_size_change_hint_callback
      nullptr,  // wireframe_enabled_callback
      0u        // vsync_event_handle
  );

  RunLoopUntilIdle();

  EXPECT_TRUE(settings_manager.WatchCalled());
  EXPECT_FALSE(delegate.SemanticsEnabled());
  EXPECT_EQ(
      delegate.SemanticsFeatures(),
      static_cast<int32_t>(flutter::AccessibilityFeatureFlag::kInvertColors));
}

// Test to make sure that PlatformView correctly registers messages sent on
// the "flutter/platform_views" channel, correctly parses the JSON it receives
// and calls the EnableWireframeCallback with the appropriate args.
TEST_F(PlatformViewTests, EnableWireframeTest) {
  sys::testing::ServiceDirectoryProvider services_provider(dispatcher());
  MockPlatformViewDelegate delegate;
  zx::eventpair a, b;
  zx::eventpair::create(/* flags */ 0u, &a, &b);
  auto view_ref = fuchsia::ui::views::ViewRef({
      .reference = std::move(a),
  });
  auto view_ref_control = fuchsia::ui::views::ViewRefControl({
      .reference = std::move(b),
  });
  flutter::TaskRunners task_runners =
      flutter::TaskRunners("test_runners", nullptr, nullptr, nullptr, nullptr);

  // Test wireframe callback function. If the message sent to the platform view
  // was properly handled and parsed, this function should be called, setting
  // |wireframe_enabled| to true.
  bool wireframe_enabled = false;
  auto EnableWireframeCallback = [&wireframe_enabled](bool should_enable) {
    wireframe_enabled = should_enable;
  };

  auto platform_view = flutter_runner::PlatformView(
      delegate,                               // delegate
      "test_platform_view",                   // label
      std::move(view_ref_control),            // view_ref_control
      std::move(view_ref),                    // view_refs
      std::move(task_runners),                // task_runners
      services_provider.service_directory(),  // runner_services
      nullptr,                  // parent_environment_service_provider_handle
      nullptr,                  // session_listener_request
      nullptr,                  // on_session_listener_error_callback
      nullptr,                  // session_metrics_did_change_callback
      nullptr,                  // session_size_change_hint_callback
      EnableWireframeCallback,  // on_enable_wireframe_callback,
      0u                        // vsync_event_handle
  );

  // Cast platform_view to its base view so we can have access to the public
  // "HandlePlatformMessage" function.
  auto base_view = dynamic_cast<flutter::PlatformView*>(&platform_view);
  EXPECT_TRUE(base_view);

  // JSON for the message to be passed into the PlatformView.
  const uint8_t txt[] =
      "{"
      "    \"method\":\"View.enableWireframe\","
      "    \"args\": {"
      "       \"enable\":true"
      "    }"
      "}";

  fml::RefPtr<flutter::PlatformMessage> message =
      fml::MakeRefCounted<flutter::PlatformMessage>(
          "flutter/platform_views",
          std::vector<uint8_t>(txt, txt + sizeof(txt)),
          fml::RefPtr<flutter::PlatformMessageResponse>());
  base_view->HandlePlatformMessage(message);

  RunLoopUntilIdle();

  EXPECT_TRUE(wireframe_enabled);
}

}  // namespace flutter_runner_test::flutter_runner_a11y_test
