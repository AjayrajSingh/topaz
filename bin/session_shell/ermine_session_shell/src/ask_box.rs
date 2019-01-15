use crate::APP;
use failure::Error;
use fidl::encoding::OutOfLine;
use fidl::endpoints::create_endpoints;
use fidl_fuchsia_math::{InsetF, SizeF};
use fidl_fuchsia_textinputmod::{
    TextInputModMarker, TextInputModProxy, TextInputModReceiverMarker, TextInputModReceiverRequest,
};
use fidl_fuchsia_ui_viewsv1::{
    CustomFocusBehavior, ViewLayout, ViewProperties, ViewProviderMarker,
};
use fidl_fuchsia_ui_viewsv1token::ViewOwnerMarker;
use fuchsia_app::client::{App, Launcher};
use fuchsia_async as fasync;
use fuchsia_scenic::{EntityNode, ImportNode, SessionPtr};
use futures::{TryFutureExt, TryStreamExt};

pub struct AskBox {
    _app: App,
    key: u32,
    pub host_node: EntityNode,
    pub text_input_mod: TextInputModProxy,
}

impl AskBox {
    fn setup_view(
        app: &App, key: u32, session: &SessionPtr,
        view_container: &fidl_fuchsia_ui_viewsv1::ViewContainerProxy, import_node: &ImportNode,
    ) -> Result<EntityNode, Error> {
        let view_provider = app.connect_to_service(ViewProviderMarker)?;
        let (view_owner_client, view_owner_server) = create_endpoints::<ViewOwnerMarker>()?;
        view_provider.create_view(view_owner_server, None)?;
        let host_node = EntityNode::new(session.clone());
        let host_import_token = host_node.export_as_request();

        view_container.add_child(key, view_owner_client, host_import_token)?;
        import_node.add_child(&host_node);
        Ok(host_node)
    }

    fn setup_text_mod_receiver(app: &App) -> Result<TextInputModProxy, Error> {
        let text_input_mod = app.connect_to_service(TextInputModMarker)?;

        let (text_input_receiver, text_input_receiver_request) =
            create_endpoints::<TextInputModReceiverMarker>()?;

        fasync::spawn(
            text_input_receiver_request
                .into_stream()?
                .map_ok(move |request| match request {
                    TextInputModReceiverRequest::UserEnteredText { text, responder } => {
                        APP.lock()
                            .handle_suggestion(Some(&text))
                            .unwrap_or_else(|e| eprintln!("handle_suggestion error: {:?}", e));
                        responder
                            .send()
                            .unwrap_or_else(|e| eprintln!("UserEnteredText send failed: {:?}", e));
                    }
                    TextInputModReceiverRequest::UserCanceled { responder } => {
                        APP.lock()
                            .handle_suggestion(None)
                            .unwrap_or_else(|e| eprintln!("handle_suggestion error: {:?}", e));
                        responder
                            .send()
                            .unwrap_or_else(|e| eprintln!("UserCanceled send failed: {:?}", e));
                    }
                })
                .try_collect::<()>()
                .unwrap_or_else(|e| eprintln!("text input receiver error: {:?}", e)),
        );

        let f = text_input_mod.listen_for_text_input(text_input_receiver);
        fasync::spawn(f.unwrap_or_else(|e| eprintln!("listen_for_text_input error: {:?}", e)));

        Ok(text_input_mod)
    }

    pub fn focus(
        &mut self, _view_container: &fidl_fuchsia_ui_viewsv1::ViewContainerProxy,
    ) -> Result<(), Error> {
        // TODO: add correct scenic focusing call here
        println!("Want to focus {}", self.key);
        Ok(())
    }

    pub fn remove(
        &mut self, view_container: &fidl_fuchsia_ui_viewsv1::ViewContainerProxy,
    ) -> Result<(), Error> {
        view_container.remove_child(self.key, None)?;
        Ok(())
    }

    pub fn new(
        key: u32, session: &SessionPtr,
        view_container: &fidl_fuchsia_ui_viewsv1::ViewContainerProxy, import_node: &ImportNode,
    ) -> Result<AskBox, Error> {
        let app = Launcher::new()?.launch(
            "fuchsia-pkg://fuchsia.com/text_input_mod#meta/text_input_mod.cmx".to_string(),
            None,
        )?;

        let host_node = Self::setup_view(&app, key, session, view_container, import_node)?;
        let text_input_mod = Self::setup_text_mod_receiver(&app)?;

        Ok(AskBox {
            _app: app,
            key,
            host_node,
            text_input_mod,
        })
    }

    pub fn layout(
        &self, view_container: &fidl_fuchsia_ui_viewsv1::ViewContainerProxy, width: f32,
        height: f32,
    ) -> Result<(), Error> {
        let x_inset = width * 0.1;
        let y_inset = height * 0.4;
        let mut view_properties = ViewProperties {
            custom_focus_behavior: Some(Box::new(CustomFocusBehavior { allow_focus: true })),
            view_layout: Some(Box::new(ViewLayout {
                inset: InsetF {
                    bottom: 0.0,
                    left: 0.0,
                    right: 0.0,
                    top: 0.0,
                },
                size: SizeF {
                    width: width - 2.0 * x_inset,
                    height: height - 2.0 * y_inset,
                },
            })),
        };
        view_container.set_child_properties(self.key, Some(OutOfLine(&mut view_properties)))?;
        self.host_node.set_translation(x_inset, y_inset, 10.0);

        Ok(())
    }
}
