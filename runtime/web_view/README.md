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
        ./magenta/scripts/run-magenta-x86-64 -g -x out/debug-x86-64/user.bootfs

Once in mxsh

        @ bootstrap launch web_view
