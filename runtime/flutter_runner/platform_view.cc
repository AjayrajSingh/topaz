// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#define RAPIDJSON_HAS_STDSTRING 1

#include "platform_view.h"

#include <sstream>

#include "flutter/lib/ui/window/pointer_data.h"
#include "lib/component/cpp/connect.h"
#include "lib/ui/gfx/cpp/math.h"
#include "rapidjson/document.h"
#include "rapidjson/stringbuffer.h"
#include "rapidjson/writer.h"
#include "vsync_waiter.h"

namespace flutter {

constexpr char kFlutterPlatformChannel[] = "flutter/platform";
constexpr char kTextInputChannel[] = "flutter/textinput";
constexpr char kKeyEventChannel[] = "flutter/keyevent";
constexpr char kAccessibilityChannel[] = "flutter/accessibility";

// FL(77): Terminate engine if Fuchsia system FIDL connections have error.
template <class T>
void SetInterfaceErrorHandler(fidl::InterfacePtr<T>& interface,
                              std::string name) {
  interface.set_error_handler([name](zx_status_t status) {
    FML_LOG(ERROR) << "Interface error on: " << name;
  });
}
template <class T>
void SetInterfaceErrorHandler(fidl::Binding<T>& binding, std::string name) {
  binding.set_error_handler([name](zx_status_t status) {
    FML_LOG(ERROR) << "Interface error on: " << name;
  });
}

PlatformView::PlatformView(
    PlatformView::Delegate& delegate, std::string debug_label,
    blink::TaskRunners task_runners,
    fidl::InterfaceHandle<fuchsia::sys::ServiceProvider>
        parent_environment_service_provider_handle,
    fidl::InterfaceRequest<fuchsia::ui::scenic::SessionListener>
        session_listener_request,
    fit::closure session_listener_error_callback,
    OnMetricsUpdate session_metrics_did_change_callback,
    OnSizeChangeHint session_size_change_hint_callback,
#ifndef SCENIC_VIEWS2
    fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewManager>
        view_manager_handle,
    fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner> view_owner,
    zx::eventpair export_token,
#endif
    fidl::InterfaceHandle<fuchsia::modular::ContextWriter>
        accessibility_context_writer,
    zx_handle_t vsync_event_handle)
    : shell::PlatformView(delegate, std::move(task_runners)),
      debug_label_(std::move(debug_label)),
      session_listener_binding_(this, std::move(session_listener_request)),
      session_listener_error_callback_(
          std::move(session_listener_error_callback)),
      metrics_changed_callback_(std::move(session_metrics_did_change_callback)),
      size_change_hint_callback_(std::move(session_size_change_hint_callback)),
#ifndef SCENIC_VIEWS2
      view_manager_(view_manager_handle.Bind()),
      view_listener_(this),
      input_listener_(this),
#endif
      ime_client_(this),
      context_writer_bridge_(std::move(accessibility_context_writer)),
      semantics_bridge_(this, &metrics_),
      surface_(std::make_unique<Surface>(debug_label_)),
      vsync_event_handle_(vsync_event_handle) {
  // Register all error handlers.
  SetInterfaceErrorHandler(session_listener_binding_, "SessionListener");
#ifndef SCENIC_VIEWS2
  SetInterfaceErrorHandler(view_manager_, "View Manager");
  SetInterfaceErrorHandler(view_, "View");
  SetInterfaceErrorHandler(input_connection_, "Input Connection");
#endif
  SetInterfaceErrorHandler(presenter_service_, "Presenter");
  SetInterfaceErrorHandler(ime_, "Input Method Editor");
  SetInterfaceErrorHandler(text_sync_service_, "Text Sync Service");
  SetInterfaceErrorHandler(clipboard_, "Clipboard");
  SetInterfaceErrorHandler(service_provider_, "Service Provider");
  SetInterfaceErrorHandler(parent_environment_service_provider_,
                           "Parent Environment Service Provider");

#ifndef SCENIC_VIEWS2
  // Create the view.
  view_manager_->CreateView(view_.NewRequest(),           // view
                            std::move(view_owner),        // view owner
                            view_listener_.NewBinding(),  // view listener
                            std::move(export_token),      // export token
                            debug_label_                  // diagnostic label
  );

  // Get the services from the created view.
  view_->GetServiceProvider(service_provider_.NewRequest());

  // Get the view container. This will need to be returned to the isolate
  // configurator so that it can setup Mozart bindings later.
  view_->GetContainer(view_container_.NewRequest());

  // Get the input connection from the services of the view.
  component::ConnectToService(service_provider_.get(),
                              input_connection_.NewRequest());

  // Set the input listener on the input connection.
  input_connection_->SetEventListener(input_listener_.NewBinding());
#endif

  // Access the clipboard.
  parent_environment_service_provider_ =
      parent_environment_service_provider_handle.Bind();
  component::ConnectToService(parent_environment_service_provider_.get(),
                              clipboard_.NewRequest());

  // Access the Presenter service to query the input path.
  // TODO(SCN-1013): Remove this wart.
  component::ConnectToService(parent_environment_service_provider_.get(),
                              presenter_service_.NewRequest());
  presenter_service_->HACK_QueryInputPath([this](bool use_legacy) {
    FXL_LOG(INFO) << "Flutter, input comes from: "
                  << (use_legacy ? "ViewManager" : "Scenic");
    HACK_legacy_input_path_ = use_legacy;  // This is early enough.
  });

  component::ConnectToService(parent_environment_service_provider_.get(),
                              text_sync_service_.NewRequest());

  // Finally! Register the native platform message handlers.
  RegisterPlatformMessageHandlers();

  // TODO(SCN-975): Re-enable.
  //   view_->GetToken(std::bind(&PlatformView::ConnectSemanticsProvider, this,
  //                             std::placeholders::_1));
}

PlatformView::~PlatformView() = default;

#ifndef SCENIC_VIEWS2
void PlatformView::OfferServiceProvider(
    fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> service_provider,
    fidl::VectorPtr<fidl::StringPtr> services) {
  view_->OfferServiceProvider(std::move(service_provider), std::move(services));
}
#endif

void PlatformView::RegisterPlatformMessageHandlers() {
  platform_message_handlers_[kFlutterPlatformChannel] =
      std::bind(&PlatformView::HandleFlutterPlatformChannelPlatformMessage,  //
                this,                                                        //
                std::placeholders::_1);
  platform_message_handlers_[kTextInputChannel] =
      std::bind(&PlatformView::HandleFlutterTextInputChannelPlatformMessage,  //
                this,                                                         //
                std::placeholders::_1);
  platform_message_handlers_[kAccessibilityChannel] =
      std::bind(&PlatformView::HandleAccessibilityChannelPlatformMessage,  //
                this,                                                      //
                std::placeholders::_1);
}

#ifndef SCENIC_VIEWS2
fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewContainer>
PlatformView::TakeViewContainer() {
  return std::move(view_container_);
}
#endif

#ifndef SCENIC_VIEWS2
// |fuchsia::ui::viewsv1::ViewListener|
void PlatformView::OnPropertiesChanged(
    fuchsia::ui::viewsv1::ViewProperties properties,
    OnPropertiesChangedCallback callback) {
  if (properties.view_layout) {
    UpdateViewportMetrics(*properties.view_layout);
  }
  callback();
}
#else
void PlatformView::OnPropertiesChanged(
    const fuchsia::ui::gfx::ViewProperties& view_properties) {
  fuchsia::ui::gfx::BoundingBox layout_box =
      scenic::ViewPropertiesLayoutBox(view_properties);

  fuchsia::ui::gfx::vec3 logical_size =
      scenic::Max(layout_box.max - layout_box.min, 0.f);

  metrics_.size.width = logical_size.x;
  metrics_.size.height = logical_size.y;
  metrics_.padding.left = view_properties.inset_from_min.x;
  metrics_.padding.top = view_properties.inset_from_min.y;
  metrics_.padding.right = view_properties.inset_from_max.x;
  metrics_.padding.bottom = view_properties.inset_from_max.y;

  FlushViewportMetrics();
}
#endif

// TODO(SCN-975): Re-enable.
// void PlatformView::ConnectSemanticsProvider(
//     fuchsia::ui::viewsv1token::ViewToken token) {
//   semantics_bridge_.SetupEnvironment(
//       token.value, parent_environment_service_provider_.get());
// }

#ifndef SCENIC_VIEWS2
void PlatformView::UpdateViewportMetrics(
    const fuchsia::ui::viewsv1::ViewLayout& layout) {
  metrics_.size.width = layout.size.width;
  metrics_.size.height = layout.size.height;
  metrics_.padding.left = layout.inset.left;
  metrics_.padding.top = layout.inset.top;
  metrics_.padding.right = layout.inset.right;
  metrics_.padding.bottom = layout.inset.bottom;

  FlushViewportMetrics();
}
#endif

void PlatformView::UpdateViewportMetrics(
    const fuchsia::ui::gfx::Metrics& metrics) {
  metrics_.scale = metrics.scale_x;

  FlushViewportMetrics();
}

void PlatformView::FlushViewportMetrics() {
  const auto scale = metrics_.scale;
  blink::ViewportMetrics metrics = {
      .device_pixel_ratio = scale,

      .physical_width = metrics_.size.width * scale,
      .physical_height = metrics_.size.height * scale,

      .physical_padding_top = metrics_.padding.top * scale,
      .physical_padding_right = metrics_.padding.right * scale,
      .physical_padding_bottom = metrics_.padding.bottom * scale,
      .physical_padding_left = metrics_.padding.left * scale,

      .physical_view_inset_top = metrics_.view_inset.top * scale,
      .physical_view_inset_right = metrics_.view_inset.right * scale,
      .physical_view_inset_bottom = metrics_.view_inset.bottom * scale,
      .physical_view_inset_left = metrics_.view_inset.left * scale,
  };

  SetViewportMetrics(metrics);
}

// |fuchsia::ui::input::InputMethodEditorClient|
void PlatformView::DidUpdateState(
    fuchsia::ui::input::TextInputState state,
    std::unique_ptr<fuchsia::ui::input::InputEvent>) {
  rapidjson::Document document;
  auto& allocator = document.GetAllocator();
  rapidjson::Value encoded_state(rapidjson::kObjectType);
  encoded_state.AddMember("text", state.text.get(), allocator);
  encoded_state.AddMember("selectionBase", state.selection.base, allocator);
  encoded_state.AddMember("selectionExtent", state.selection.extent, allocator);
  switch (state.selection.affinity) {
    case fuchsia::ui::input::TextAffinity::UPSTREAM:
      encoded_state.AddMember("selectionAffinity",
                              rapidjson::Value("TextAffinity.upstream"),
                              allocator);
      break;
    case fuchsia::ui::input::TextAffinity::DOWNSTREAM:
      encoded_state.AddMember("selectionAffinity",
                              rapidjson::Value("TextAffinity.downstream"),
                              allocator);
      break;
  }
  encoded_state.AddMember("selectionIsDirectional", true, allocator);
  encoded_state.AddMember("composingBase", state.composing.start, allocator);
  encoded_state.AddMember("composingExtent", state.composing.end, allocator);

  rapidjson::Value args(rapidjson::kArrayType);
  args.PushBack(current_text_input_client_, allocator);
  args.PushBack(encoded_state, allocator);

  document.SetObject();
  document.AddMember("method",
                     rapidjson::Value("TextInputClient.updateEditingState"),
                     allocator);
  document.AddMember("args", args, allocator);

  rapidjson::StringBuffer buffer;
  rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
  document.Accept(writer);

  const uint8_t* data = reinterpret_cast<const uint8_t*>(buffer.GetString());
  DispatchPlatformMessage(fml::MakeRefCounted<blink::PlatformMessage>(
      kTextInputChannel,                                    // channel
      std::vector<uint8_t>(data, data + buffer.GetSize()),  // message
      nullptr)                                              // response
  );
  last_text_state_ =
      std::make_unique<fuchsia::ui::input::TextInputState>(state);
}

// |fuchsia::ui::input::InputMethodEditorClient|
void PlatformView::OnAction(fuchsia::ui::input::InputMethodAction action) {
  rapidjson::Document document;
  auto& allocator = document.GetAllocator();

  rapidjson::Value args(rapidjson::kArrayType);
  args.PushBack(current_text_input_client_, allocator);

  // Done is currently the only text input action defined by Flutter.
  args.PushBack("TextInputAction.done", allocator);

  document.SetObject();
  document.AddMember(
      "method", rapidjson::Value("TextInputClient.performAction"), allocator);
  document.AddMember("args", args, allocator);

  rapidjson::StringBuffer buffer;
  rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
  document.Accept(writer);

  const uint8_t* data = reinterpret_cast<const uint8_t*>(buffer.GetString());
  DispatchPlatformMessage(fml::MakeRefCounted<blink::PlatformMessage>(
      kTextInputChannel,                                    // channel
      std::vector<uint8_t>(data, data + buffer.GetSize()),  // message
      nullptr)                                              // response
  );
}

// |fuchsia::ui::input::InputListener|
void PlatformView::OnEvent(fuchsia::ui::input::InputEvent event,
                           OnEventCallback callback) {
  using Type = fuchsia::ui::input::InputEvent::Tag;
  switch (event.Which()) {
    case Type::kPointer:
      callback(OnHandlePointerEvent(event.pointer()));
      return;
    case Type::kKeyboard:
      callback(OnHandleKeyboardEvent(event.keyboard()));
      return;
    case Type::kFocus:
      callback(OnHandleFocusEvent(event.focus()));
      return;
    default:
      break;
  }

  callback(false);
}

void PlatformView::OnScenicError(fidl::StringPtr error) {
  FML_LOG(ERROR) << "Session error: " << error;
  session_listener_error_callback_();
}

void PlatformView::OnScenicEvent(
    fidl::VectorPtr<fuchsia::ui::scenic::Event> events) {
  for (const auto& event : *events) {
    switch (event.Which()) {
      case fuchsia::ui::scenic::Event::Tag::kGfx:
        switch (event.gfx().Which()) {
          case fuchsia::ui::gfx::Event::Tag::kMetrics: {
            if (event.gfx().metrics().metrics != scenic_metrics_) {
              scenic_metrics_ = std::move(event.gfx().metrics().metrics);
              metrics_changed_callback_(scenic_metrics_);
              UpdateViewportMetrics(scenic_metrics_);
            }
            break;
          }
          case fuchsia::ui::gfx::Event::Tag::kSizeChangeHint: {
            size_change_hint_callback_(
                event.gfx().size_change_hint().width_change_factor,
                event.gfx().size_change_hint().height_change_factor);
            break;
          }
          case fuchsia::ui::gfx::Event::Tag::kViewPropertiesChanged: {
#ifdef SCENIC_VIEWS2
            OnPropertiesChanged(
                std::move(event.gfx().view_properties_changed().properties));
#endif
            break;
          }
          case fuchsia::ui::gfx::Event::Tag::kImportUnbound:
            FML_LOG(WARNING)
                << "Flutter PlatformView::OnScenicEvent: Unhandled GFX event "
                   "(fuchsia.ui.gfx.ImportUnboundEvent).";
            break;
          case fuchsia::ui::gfx::Event::Tag::kViewConnected:
            FML_LOG(WARNING)
                << "Flutter PlatformView::OnScenicEvent: Unhandled GFX event "
                   "(fuchsia.ui.gfx.ViewConnectedEvent).";
            break;
          case fuchsia::ui::gfx::Event::Tag::kViewDisconnected:
            FML_LOG(WARNING)
                << "Flutter PlatformView::OnScenicEvent: Unhandled GFX event "
                   "(fuchsia.ui.gfx.ViewDisconnectedEvent).";
            break;
          case fuchsia::ui::gfx::Event::Tag::kViewHolderDisconnected:
            FML_LOG(WARNING)
                << "Flutter PlatformView::OnScenicEvent: Unhandled GFX event "
                   "(fuchsia.ui.gfx.ViewHolderDisconnectedEvent).";
            break;
          case fuchsia::ui::gfx::Event::Tag::kViewAttachedToScene:
            FML_LOG(WARNING)
                << "Flutter PlatformView::OnScenicEvent: Unhandled GFX event "
                   "(fuchsia.ui.gfx.ViewAttachedToScene).";
            break;
          case fuchsia::ui::gfx::Event::Tag::kViewDetachedFromScene:
            FML_LOG(WARNING)
                << "Flutter PlatformView::OnScenicEvent: Unhandled GFX event "
                   "(fuchsia.ui.gfx.ViewDetachedFromScene).";
            break;
          case fuchsia::ui::gfx::Event::Tag::kViewStateChanged:
            FML_LOG(WARNING)
                << "Flutter PlatformView::OnScenicEvent: Unhandled GFX event "
                   "(fuchsia.ui.gfx.ViewStateChanged).";
            break;
          case fuchsia::ui::gfx::Event::Tag::Invalid:
            FXL_DCHECK(false)
                << "Flutter PlatformView::OnScenicEvent: Got an invalid GFX "
                   "event.";
            break;
        }
        break;
      case fuchsia::ui::scenic::Event::Tag::kInput:
        switch (event.input().Which()) {
          case fuchsia::ui::input::InputEvent::Tag::kFocus: {
            OnHandleFocusEvent(event.input().focus());
            break;
          }
          case fuchsia::ui::input::InputEvent::Tag::kPointer: {
            OnHandlePointerEvent(event.input().pointer());
            break;
          }
          case fuchsia::ui::input::InputEvent::Tag::kKeyboard: {
            OnHandleKeyboardEvent(event.input().keyboard());
            break;
          }
          default: {
            FML_LOG(WARNING) << "Flutter PlatformView::OnScenicEvent: "
                                "Unhandled input event.";
          }
        }
        break;
      default: {
        FML_LOG(WARNING)
            << "Flutter PlatformView::OnScenicEvent: Unhandled Scenic event.";
      }
    }
  }
}

static blink::PointerData::Change GetChangeFromPointerEventPhase(
    fuchsia::ui::input::PointerEventPhase phase) {
  switch (phase) {
    case fuchsia::ui::input::PointerEventPhase::ADD:
      return blink::PointerData::Change::kAdd;
    case fuchsia::ui::input::PointerEventPhase::HOVER:
      return blink::PointerData::Change::kHover;
    case fuchsia::ui::input::PointerEventPhase::DOWN:
      return blink::PointerData::Change::kDown;
    case fuchsia::ui::input::PointerEventPhase::MOVE:
      return blink::PointerData::Change::kMove;
    case fuchsia::ui::input::PointerEventPhase::UP:
      return blink::PointerData::Change::kUp;
    case fuchsia::ui::input::PointerEventPhase::REMOVE:
      return blink::PointerData::Change::kRemove;
    case fuchsia::ui::input::PointerEventPhase::CANCEL:
      return blink::PointerData::Change::kCancel;
    default:
      return blink::PointerData::Change::kCancel;
  }
}

static blink::PointerData::DeviceKind GetKindFromPointerType(
    fuchsia::ui::input::PointerEventType type) {
  switch (type) {
    case fuchsia::ui::input::PointerEventType::TOUCH:
      return blink::PointerData::DeviceKind::kTouch;
    case fuchsia::ui::input::PointerEventType::MOUSE:
      return blink::PointerData::DeviceKind::kMouse;
    default:
      return blink::PointerData::DeviceKind::kTouch;
  }
}

bool PlatformView::OnHandlePointerEvent(
    const fuchsia::ui::input::PointerEvent& pointer) {
  blink::PointerData pointer_data;
  pointer_data.time_stamp = pointer.event_time / 1000;
  pointer_data.change = GetChangeFromPointerEventPhase(pointer.phase);
  pointer_data.kind = GetKindFromPointerType(pointer.type);
  pointer_data.device = pointer.pointer_id;
  pointer_data.physical_x = pointer.x * metrics_.scale;
  pointer_data.physical_y = pointer.y * metrics_.scale;
  // Buttons are single bit values starting with kMousePrimaryButton = 1.
  pointer_data.buttons = static_cast<uint64_t>(pointer.buttons);

  switch (pointer_data.change) {
    case blink::PointerData::Change::kDown:
      down_pointers_.insert(pointer_data.device);
      break;
    case blink::PointerData::Change::kCancel:
    case blink::PointerData::Change::kUp:
      down_pointers_.erase(pointer_data.device);
      break;
    case blink::PointerData::Change::kMove:
      if (down_pointers_.count(pointer_data.device) == 0) {
        pointer_data.change = blink::PointerData::Change::kHover;
      }
      break;
    case blink::PointerData::Change::kAdd:
      if (down_pointers_.count(pointer_data.device) != 0) {
        FML_DLOG(ERROR) << "Received add event for down pointer.";
      }
      break;
    case blink::PointerData::Change::kRemove:
      if (down_pointers_.count(pointer_data.device) != 0) {
        FML_DLOG(ERROR) << "Received remove event for down pointer.";
      }
      break;
    case blink::PointerData::Change::kHover:
      if (down_pointers_.count(pointer_data.device) != 0) {
        FML_DLOG(ERROR) << "Received hover event for down pointer.";
      }
      break;
  }

  auto packet = std::make_unique<blink::PointerDataPacket>(1);
  packet->SetPointerData(0, pointer_data);
  DispatchPointerDataPacket(std::move(packet));
  return true;
}

bool PlatformView::OnHandleKeyboardEvent(
    const fuchsia::ui::input::KeyboardEvent& keyboard) {
  const char* type = nullptr;
  if (keyboard.phase == fuchsia::ui::input::KeyboardEventPhase::PRESSED) {
    type = "keydown";
  } else if (keyboard.phase == fuchsia::ui::input::KeyboardEventPhase::REPEAT) {
    type = "keydown";  // TODO change this to keyrepeat
  } else if (keyboard.phase ==
             fuchsia::ui::input::KeyboardEventPhase::RELEASED) {
    type = "keyup";
  }

  if (type == nullptr) {
    FML_DLOG(ERROR) << "Unknown key event phase.";
    return false;
  }

  rapidjson::Document document;
  auto& allocator = document.GetAllocator();
  document.SetObject();
  document.AddMember("type", rapidjson::Value(type, strlen(type)), allocator);
  document.AddMember("keymap", rapidjson::Value("fuchsia"), allocator);
  document.AddMember("hidUsage", keyboard.hid_usage, allocator);
  document.AddMember("codePoint", keyboard.code_point, allocator);
  document.AddMember("modifiers", keyboard.modifiers, allocator);
  rapidjson::StringBuffer buffer;
  rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
  document.Accept(writer);

  const uint8_t* data = reinterpret_cast<const uint8_t*>(buffer.GetString());
  DispatchPlatformMessage(fml::MakeRefCounted<blink::PlatformMessage>(
      kKeyEventChannel,                                     // channel
      std::vector<uint8_t>(data, data + buffer.GetSize()),  // data
      nullptr)                                              // response
  );

  return true;
}

bool PlatformView::OnHandleFocusEvent(
    const fuchsia::ui::input::FocusEvent& focus) {
  // Ensure last_text_state_ is set to make sure Flutter actually wants an IME.
  if (focus.focused && last_text_state_ != nullptr) {
    ActivateIme();
    return true;
  } else if (!focus.focused) {
    DeactivateIme();
    return true;
  }
  return false;
}

void PlatformView::ActivateIme() {
  FXL_DCHECK(last_text_state_);

#ifndef SCENIC_VIEWS2
  if (HACK_legacy_input_path_) {
    input_connection_->GetInputMethodEditor(
        fuchsia::ui::input::KeyboardType::TEXT,       // keyboard type
        fuchsia::ui::input::InputMethodAction::DONE,  // input method action
        *last_text_state_,                            // initial state
        ime_client_.NewBinding(),                     // client
        ime_.NewRequest()                             // editor
    );
  } else
#endif
  {
    text_sync_service_->GetInputMethodEditor(
        fuchsia::ui::input::KeyboardType::TEXT,       // keyboard type
        fuchsia::ui::input::InputMethodAction::DONE,  // input method action
        *last_text_state_,                            // initial state
        ime_client_.NewBinding(),                     // client
        ime_.NewRequest()                             // editor
    );
  }
}

void PlatformView::DeactivateIme() {
  if (ime_) {
#ifndef SCENIC_VIEWS2
    if (HACK_legacy_input_path_) {
      input_connection_->HideKeyboard();
    } else
#endif
    {
      text_sync_service_->HideKeyboard();
    }
    ime_ = nullptr;
  }
  if (ime_client_.is_bound()) {
    ime_client_.Unbind();
  }
}

// |shell::PlatformView|
std::unique_ptr<shell::VsyncWaiter> PlatformView::CreateVSyncWaiter() {
  return std::make_unique<flutter::VsyncWaiter>(
      debug_label_, vsync_event_handle_, task_runners_);
}

// |shell::PlatformView|
std::unique_ptr<shell::Surface> PlatformView::CreateRenderingSurface() {
  // This platform does not repeatly lose and gain a surface connection. So the
  // surface is setup once during platform view setup and and returned to the
  // shell on the initial (and only) |NotifyCreated| call.
  return std::move(surface_);
}

// |shell::PlatformView|
void PlatformView::HandlePlatformMessage(
    fml::RefPtr<blink::PlatformMessage> message) {
  if (!message) {
    return;
  }
  auto found = platform_message_handlers_.find(message->channel());
  if (found == platform_message_handlers_.end()) {
    FML_DLOG(ERROR)
        << "Platform view received message on channel '" << message->channel()
        << "' with no registed handler. And empty response will be generated. "
           "Please implement the native message handler.";
    PlatformView::HandlePlatformMessage(std::move(message));
    return;
  }
  found->second(std::move(message));
}

// |shell::PlatformView|
void PlatformView::UpdateSemantics(
    blink::SemanticsNodeUpdates update,
    blink::CustomAccessibilityActionUpdates actions) {
  // TODO(MI4-1262): Figure out if the context_writer_bridge should be removed
  // as it is unused.
  // context_writer_bridge_.UpdateSemantics(update);
  semantics_bridge_.UpdateSemantics(update);
}

// Channel handler for kAccessibilityChannel
void PlatformView::HandleAccessibilityChannelPlatformMessage(
    fml::RefPtr<blink::PlatformMessage> message) {
  FML_DCHECK(message->channel() == kAccessibilityChannel);
}

// Channel handler for kFlutterPlatformChannel
void PlatformView::HandleFlutterPlatformChannelPlatformMessage(
    fml::RefPtr<blink::PlatformMessage> message) {
  FML_DCHECK(message->channel() == kFlutterPlatformChannel);
  const auto& data = message->data();
  rapidjson::Document document;
  document.Parse(reinterpret_cast<const char*>(data.data()), data.size());
  if (document.HasParseError() || !document.IsObject()) {
    return;
  }

  auto root = document.GetObject();
  auto method = root.FindMember("method");
  if (method == root.MemberEnd() || !method->value.IsString()) {
    return;
  }

  fml::RefPtr<blink::PlatformMessageResponse> response = message->response();
  if (method->value == "Clipboard.setData") {
    auto text = root["args"]["text"].GetString();
    clipboard_->Push(text);
    response->CompleteEmpty();
  } else if (method->value == "Clipboard.getData") {
    clipboard_->Peek([response](fidl::StringPtr text) {
      rapidjson::StringBuffer json_buffer;
      rapidjson::Writer<rapidjson::StringBuffer> writer(json_buffer);
      writer.StartArray();
      writer.StartObject();
      writer.Key("text");
      writer.String(text.get());
      writer.EndObject();
      writer.EndArray();
      std::string result = json_buffer.GetString();
      response->Complete(std::make_unique<fml::DataMapping>(
          std::vector<uint8_t>{result.begin(), result.end()}));
    });
  } else {
    response->CompleteEmpty();
  }
}

// Channel handler for kTextInputChannel
void PlatformView::HandleFlutterTextInputChannelPlatformMessage(
    fml::RefPtr<blink::PlatformMessage> message) {
  FML_DCHECK(message->channel() == kTextInputChannel);
  const auto& data = message->data();
  rapidjson::Document document;
  document.Parse(reinterpret_cast<const char*>(data.data()), data.size());
  if (document.HasParseError() || !document.IsObject()) {
    return;
  }
  auto root = document.GetObject();
  auto method = root.FindMember("method");
  if (method == root.MemberEnd() || !method->value.IsString()) {
    return;
  }

  if (method->value == "TextInput.show") {
    if (ime_) {
#ifndef SCENIC_VIEWS2
      if (HACK_legacy_input_path_) {
        input_connection_->ShowKeyboard();
      } else
#endif
      {
        text_sync_service_->ShowKeyboard();
      }
    }
  } else if (method->value == "TextInput.hide") {
    if (ime_) {
#ifndef SCENIC_VIEWS2
      if (HACK_legacy_input_path_) {
        input_connection_->HideKeyboard();
      } else
#endif
      {
        text_sync_service_->HideKeyboard();
      }
    }
  } else if (method->value == "TextInput.setClient") {
    current_text_input_client_ = 0;
    DeactivateIme();
    auto args = root.FindMember("args");
    if (args == root.MemberEnd() || !args->value.IsArray() ||
        args->value.Size() != 2)
      return;
    const auto& configuration = args->value[1];
    if (!configuration.IsObject()) {
      return;
    }
    // TODO(abarth): Read the keyboard type from the configuration.
    current_text_input_client_ = args->value[0].GetInt();

    auto initial_text_input_state = fuchsia::ui::input::TextInputState{};
    initial_text_input_state.text = "";
    last_text_state_ = std::make_unique<fuchsia::ui::input::TextInputState>(
        initial_text_input_state);
    ActivateIme();
  } else if (method->value == "TextInput.setEditingState") {
    if (ime_) {
      auto args_it = root.FindMember("args");
      if (args_it == root.MemberEnd() || !args_it->value.IsObject()) {
        return;
      }
      const auto& args = args_it->value;
      fuchsia::ui::input::TextInputState state;
      state.text = "";
      // TODO(abarth): Deserialize state.
      auto text = args.FindMember("text");
      if (text != args.MemberEnd() && text->value.IsString())
        state.text = text->value.GetString();
      auto selection_base = args.FindMember("selectionBase");
      if (selection_base != args.MemberEnd() && selection_base->value.IsInt())
        state.selection.base = selection_base->value.GetInt();
      auto selection_extent = args.FindMember("selectionExtent");
      if (selection_extent != args.MemberEnd() &&
          selection_extent->value.IsInt())
        state.selection.extent = selection_extent->value.GetInt();
      auto selection_affinity = args.FindMember("selectionAffinity");
      if (selection_affinity != args.MemberEnd() &&
          selection_affinity->value.IsString() &&
          selection_affinity->value == "TextAffinity.upstream")
        state.selection.affinity = fuchsia::ui::input::TextAffinity::UPSTREAM;
      else
        state.selection.affinity = fuchsia::ui::input::TextAffinity::DOWNSTREAM;
      // We ignore selectionIsDirectional because that concept doesn't exist on
      // Fuchsia.
      auto composing_base = args.FindMember("composingBase");
      if (composing_base != args.MemberEnd() && composing_base->value.IsInt())
        state.composing.start = composing_base->value.GetInt();
      auto composing_extent = args.FindMember("composingExtent");
      if (composing_extent != args.MemberEnd() &&
          composing_extent->value.IsInt())
        state.composing.end = composing_extent->value.GetInt();
      ime_->SetState(std::move(state));
    }
  } else if (method->value == "TextInput.clearClient") {
    current_text_input_client_ = 0;
    last_text_state_ = nullptr;
    DeactivateIme();
  } else {
    FML_DLOG(ERROR) << "Unknown " << message->channel() << " method "
                    << method->value.GetString();
  }
}

}  // namespace flutter
