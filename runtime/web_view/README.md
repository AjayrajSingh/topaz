Fuchsia Web View
=======================================

This repository contains the Fuchsia-specific code wrapping the web view class from third_party/webkit/Source/WebKit/fuchsia/WebView.h. 

To get the source for the web view:

        cd apps
        git clone https://fuchsia.googlesource.com/web_view
        
To get the prebuilt dependencies:

        cd apps/web_view
        ./scripts/download-web-view-prebuilts.sh

After that, to build:

        ./packages/gn/gen.py -m default,web_view
        ./buildtools/ninja -C out/debug-x86-64

Once built, load the user.bootfs on your device as normal.

Once in a non-mxsh shell

        launch web_view

You can pass a URL as a parameter to the launch. Control-C will exit the web module.

### Updating the Prebuilts

Follow the instructions at https://fuchsia.googlesource.com/third_party/webkit/ to build webkit. Then

    ./build_webkit.sh -p -l

to build the release version of webkit and copy it, the webview header and all of the dependencies to ./prebuilt.

Edit prebuilt.tag and replace the git commit hash in that file with the one for the latest commit in the webkit directory. Then

    ./scripts/upload-web-view-prebuilts.sh

Commit the changed prebuild.tag file and the next time web_view users update they will get the updated prebuilts.  
