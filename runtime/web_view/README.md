Fuchsia Web View
=======================================

This repository contains the Fuchsia-specific code wrapping the web view class
from `third_party/webkit/Source/WebKit/fuchsia/WebView.h`.

The build is integrated into the normal Fuchsia build process, but due to its
heft the default build uses prebuilt artifacts for webkit itself. To build all
dependencies locally, add `use_prebuilt_webkit=false` to your GN arguments and
add 'webkit' to your module set:

```
fx set x64 --packages topaz/packages/default,topaz/packages/webkit --args use_prebuilt_webkit=false
```

## Updating the Prebuilt WebKit

To update the version of the prebuilt library used for building web_view:

* Make changes to the webkit repository at `//third_party/webkit` and submit.
* Wait for the automated builder to build and upload the new version of prebuilt
  webkit shared library (`libwebkit.so`).
* Edit `scripts/download-livwebkit.sh` file and update the `WEBKIT_REVISION`
  value to match the new commit hash of the `//third_party/webkit` repository.
* Locally test it by running `scripts/download-libwebkit.sh` manually.
* Commit the update revision in `scripts/download-libwebkit.sh`.

Once the above steps are followed, the newer version of prebuilt webkit library
will be downloaded as part of the `jiri update` process as an update hook.

## Experimental Entity Extraction

There is experimental web entity extraction support that can be enabled by
passing `--args experimental_web_entity_extraction=true` to `fx set`. It parses
entities in microdata or JSON-LD formats from web pages and exposes them to the
context service.
