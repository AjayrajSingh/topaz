// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <fuchsia/io/cpp/fidl.h>
#include <lib/async/default.h>
#include <lib/fdio/directory.h>
#include <lib/fdio/fd.h>
#include <lib/fdio/fdio.h>
#include <lib/inspect/reader.h>
#include <lib/inspect/testing/inspect.h>

#include "gmock/gmock.h"
#include "lib/inspect/deprecated/expose.h"
#include "lib/sys/cpp/testing/test_with_environment.h"
#include "src/lib/files/glob.h"
#include "src/lib/fxl/strings/substitute.h"

namespace {

using ::fxl::Substitute;
using sys::testing::EnclosingEnvironment;
using ::testing::ElementsAre;
using ::testing::UnorderedElementsAre;
using namespace inspect::testing;

constexpr char kTestComponent[] =
    "fuchsia-pkg://fuchsia.com/dart_inspect_vmo_test_writer#meta/"
    "dart_inspect_vmo_test_writer.cmx";
constexpr char kTestProcessName[] = "dart_inspect_vmo_test_writer.cmx";

class InspectTest : public sys::testing::TestWithEnvironment {
 protected:
  InspectTest() {
    fuchsia::sys::LaunchInfo launch_info;
    launch_info.url = kTestComponent;

    environment_ = CreateNewEnclosingEnvironment("test", CreateServices());
    environment_->CreateComponent(std::move(launch_info),
                                  controller_.NewRequest());
    bool ready = false;
    controller_.events().OnDirectoryReady = [&ready] { ready = true; };
    RunLoopWithTimeoutOrUntil([&ready] { return ready; }, zx::sec(100));
    if (!ready) {
      printf("The output directory is not ready\n");
    }
  }
  ~InspectTest() { CheckShutdown(); }

  void CheckShutdown() {
    controller_->Kill();
    bool done = false;
    controller_.events().OnTerminated =
        [&done](int64_t code, fuchsia::sys::TerminationReason reason) {
          ASSERT_EQ(fuchsia::sys::TerminationReason::EXITED, reason);
          done = true;
        };
    ASSERT_TRUE(
        RunLoopWithTimeoutOrUntil([&done] { return done; }, zx::sec(100)));
  }

  // Open the root object connection on the given sync pointer.
  // Returns ZX_OK on success.
  zx_status_t GetInspectVmo(zx::vmo* out_vmo) {
    files::Glob glob(Substitute(
        "/hub/r/test/*/c/*/*/c/$0/*/out/debug/root.inspect", kTestProcessName));
    if (glob.size() == 0) {
      printf("Size == 0\n");
      return ZX_ERR_NOT_FOUND;
    }

    fuchsia::io::FileSyncPtr file;
    zx_status_t status;
    status = fdio_open(std::string(*glob.begin()).c_str(),
                       fuchsia::io::OPEN_RIGHT_READABLE,
                       file.NewRequest().TakeChannel().release());
    if (status != ZX_OK) {
      printf("Status bad %d\n", status);
      return status;
    }

    EXPECT_TRUE(file.is_bound());

    fuchsia::io::NodeInfo info;
    auto get_status = file->Describe(&info);
    if (get_status != ZX_OK) {
      printf("get failed\n");
      return get_status;
    }

    if (!info.is_vmofile()) {
      printf("not a vmofile");
      return ZX_ERR_NOT_FOUND;
    }

    *out_vmo = std::move(info.vmofile().vmo);
    return ZX_OK;
  }

 private:
  std::unique_ptr<EnclosingEnvironment> environment_;
  fuchsia::sys::ComponentControllerPtr controller_;
};

TEST_F(InspectTest, ReadHierarchy) {
  zx::vmo vmo;
  ASSERT_EQ(ZX_OK, GetInspectVmo(&vmo));
  auto result = inspect::ReadFromVmo(std::move(vmo));
  ASSERT_TRUE(result.is_ok());
  inspect::ObjectHierarchy hierarchy = result.take_value();
  EXPECT_THAT(
      hierarchy,
      AllOf(
          NodeMatches(NameMatches("root")),
          ChildrenMatch(UnorderedElementsAre(
              AllOf(NodeMatches(AllOf(
                        NameMatches("t1"),
                        PropertyList(UnorderedElementsAre(
                            StringPropertyIs("version", "1.0"),
                            ByteVectorPropertyIs(
                                "frame", std::vector<uint8_t>({0, 0, 0})))),
                        MetricList(
                            UnorderedElementsAre(IntMetricIs("value", -10))))),
                    ChildrenMatch(UnorderedElementsAre(
                        NodeMatches(AllOf(NameMatches("item-0x0"),
                                          MetricList(UnorderedElementsAre(
                                              IntMetricIs("value", 10))))),
                        NodeMatches(AllOf(NameMatches("item-0x1"),
                                          MetricList(UnorderedElementsAre(
                                              IntMetricIs("value", 100)))))

                            ))),
              AllOf(
                  NodeMatches(AllOf(
                      NameMatches("t2"),
                      PropertyList(UnorderedElementsAre(
                          StringPropertyIs("version", "1.0"),
                          ByteVectorPropertyIs(
                              "frame", std::vector<uint8_t>({0, 0, 0})))),
                      MetricList(
                          UnorderedElementsAre(IntMetricIs("value", -10))))),
                  ChildrenMatch(UnorderedElementsAre(NodeMatches(AllOf(
                      NameMatches("item-0x2"), MetricList(UnorderedElementsAre(
                                                   IntMetricIs("value", 4)))))))

                      )))));
}

}  // namespace
