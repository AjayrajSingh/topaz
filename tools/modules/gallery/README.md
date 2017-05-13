Gallery
=======

This directory contains a gallery module implementation, where users can search
for images using Google Image Search, and send the results back to the parent
module.

If you wish to use the Gallery Module to embed images into your own modules, you
can follow the steps below.

## Start the Gallery Module

In your parent module's code, you can launch the Gallery module by calling the
`StartModuleInShell` method on `ModuleContext`. The URL of the
gallery module is `file:///system/apps/gallery`. An example code for starting a
new gallery module instance might look like this (all code examples below are in
Dart):

```dart
// NOTE: These proxy objects should be defined as class fields so that they are
// not garbage collected while bound to the FIDL channel. Close the channels
// when they are no longer needed. This applies to all proxy objects that appear
// in the examples.
ServiceProviderProxy incomingServices = new ServiceProviderProxy();
ModuleControllerProxy moduleController = new ModuleControllerProxy();

moduleContext.startModuleInShell(
  'gallery',                        // name of the child module
  'file:///system/apps/gallery',    // URL of the gallery module
  'gallery',                        // name of the link to be provided
  null,                             // outgoing service provider
  incomingServices.ctrl.request(),  // incoming service provider
  moduleController.ctrl.request(),  // module controller
  'h',                              // means 'hierarchical' relationship
);
```

The `incomingServices` should be requested so that you can obtain the
`GalleryService` interface out of it. `GalleryService` interface lets you
subscribe to the gallery module events and get notified when the user selects
some images and taps the "ADD" button.

The `moduleController` should also be requested, because you need to `stop()`
the gallery module after getting the list of selected images on the parent side.
(Because modules cannot stop themselves.)

NOTE: Currently we are using the hierarchical relationship (the 'h' parameter)
between the parent and the gallery module, but the story shell APIs are expected
to change soon.


## Providing an Initial Query Text

Optionally, if you wish to provide an initial query text to gallery module, you
can set the query text in the `Link` instance being provided to the gallery. In
the current implementation, gallery module expects the query string to be stored
under:

```json
{
  "image search": {
    "query": <query string>
  }
}
```

in the provided `Link`.

```dart
// Do the following before calling moduleContext.startModuleInShell.
LinkProxy link = new LinkProxy();
moduleContext.getLink('gallery', link.ctrl.request());

link.set(const <String>['image search', 'query'], JSON.encode('GOTG 2'));

// We're done using this link, so we can close it right here.
link.ctrl.close();
```


## Receive Selected Images from the Gallery Module

Once the `incomingServices` interface is obtained (which is of `ServiceProvider`
type), you can obtain the `GalleryService` interface.

```dart
GalleryServiceProxy galleryService = new GalleryServiceProxy();
connectToService(incomingServices, galleryService.ctrl);
```

The `GalleryService` interface defines two methods, `subscribe()` and
`unsubscribe()`, which both take a message queue token. You can obtain a
`MessageQueue` from `ComponentContext`, and then obtain the token from the
obtained `MessageQueue`. After subscribing, you can get notified when the user
taps the "ADD" button after selecting some images. The message is a JSON encoded
string in the following format:

```json
{
  "selected_images": <list of selected images>
}
```

The following example code shows how you might subscribe and handle the
notification.

```dart
ComponentContextProxy componentContext = new ComponentContextProxy();
moduleContext.getComponentContext(componentContext.ctrl.request());

MessageQueueProxy messageQueue = new MessageQueueProxy();
componentContext.obtainMessageQueue(
  'gallery',
  messageQueue.ctrl.request(),
);

// Subscribe to the gallery service notification.
messageQueue.getToken((String token) {
  galleryService.subscribe(token);
  // and remember the token for unsubscribing later...
});

// Handle the notification.
messageQueue.receive(_handleSelectedImages);


// ------ in the same class ------
void _handleSelectedImages(String message) {
  // Decode the message.
  Map<String, dynamic> decoded = JSON.decode(message);

  if (decoded['selected_images'] != null) {
    List<String> imageUrls = decoded['selected_images'];
    // Do something with the image urls...
  }

  // Close the gallery module (because the gallery module cannot close itself.)
  moduleController.stop(() {});

  // Receive further messages that might come to this message queue.
  messageQueue.receive(_handleSelectedImages);
}
```

The name `gallery` provided when obtaining the `MessageQueue` has to be unique
only within the calling module, and this does not necessarily have to match the
name of the `Link` instance. Using the same message queue name will guarantee
that the same `MessageQueue` instance is obtained even when the story is
re-inflated later or on a different device.


## Working Example

To see a fully working example code, please refer to the model class of the
chat_conversation module implemented [here][conversation-module-model].



[conversation-module-model]: https://fuchsia.googlesource.com/modules/chat/+/master/modules/conversation/lib/src/modular/conversation_module_model.dart
