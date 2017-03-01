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

        ./packages/gn/gen.py --args=netstack2=false -m default,web_view
        ./buildtools/ninja -C out/debug-x86-64

Once built, load the user.bootfs on your device as normal.

Once in a non-mxsh shell

        launch web_view

You can pass a URL as a parameter to the launch. Control-C will exit the web module.
