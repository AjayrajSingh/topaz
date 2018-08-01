// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/flutter_runner/task_runner_adapter.h"

#include "flutter/fml/message_loop_impl.h"

namespace flutter {

class CompatTaskRunner : public fml::TaskRunner {
 public:
  CompatTaskRunner(fxl::RefPtr<fxl::TaskRunner> runner)
      : fml::TaskRunner(nullptr), forwarding_target_(std::move(runner)) {
    FML_DCHECK(forwarding_target_);
  }

  void PostTask(fml::closure task) override {
    forwarding_target_->PostTask(std::move(task));
  }

  void PostTaskForTime(fml::closure task, fml::TimePoint target_time) override {
    forwarding_target_->PostTaskForTime(
        std::move(task),
        fxl::TimePoint::FromEpochDelta(fxl::TimeDelta::FromNanoseconds(
            target_time.ToEpochDelta().ToNanoseconds())));
  }

  void PostDelayedTask(fml::closure task, fml::TimeDelta delay) override {
    forwarding_target_->PostDelayedTask(
        std::move(task),
        fxl::TimeDelta::FromNanoseconds(delay.ToNanoseconds()));
  }

  bool RunsTasksOnCurrentThread() override {
    return forwarding_target_->RunsTasksOnCurrentThread();
  }

 private:
  fxl::RefPtr<fxl::TaskRunner> forwarding_target_;

  FML_DISALLOW_COPY_AND_ASSIGN(CompatTaskRunner);
  FML_FRIEND_MAKE_REF_COUNTED(CompatTaskRunner);
  FML_FRIEND_REF_COUNTED_THREAD_SAFE(CompatTaskRunner);
};

fml::RefPtr<fml::TaskRunner> CreateFMLTaskRunner(
    fxl::RefPtr<fxl::TaskRunner> runner) {
  return fml::MakeRefCounted<CompatTaskRunner>(std::move(runner));
}

}  // namespace flutter
