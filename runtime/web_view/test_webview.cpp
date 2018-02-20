// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "WebView.h"

#include <iostream>
#include <vector>

#include <zircon/pixelformat.h>

using namespace std;

int main(int argc, const char** argv) {
    size_t kTestWidth = 1024;
    size_t kTestHeight = 728;
    auto format = ZX_PIXEL_FORMAT_RGB_x888;

    vector<unsigned char> buffer(kTestWidth * kTestHeight * 4);

    WebView webView;
    webView.setup(&buffer[0], format, kTestWidth, kTestHeight, kTestWidth* 4);
    webView.setURL("https://google.com/");

    webView.setFocused(true);
    webView.setVisible(true);

    while (!webView.isMainFrameLoaded()) {
        webView.iterateEventLoop();
        webView.layoutAndPaint();
    }

    // Test that some JS doesn't crash.
    webView.stringByEvaluatingJavaScriptFromString("");
    webView.stringByEvaluatingJavaScriptFromString("1+1");
    webView.stringByEvaluatingJavaScriptFromString("asdfadsfa");
    webView.stringByEvaluatingJavaScriptFromString("(function(){ return 'hello';})()");
    webView.stringByEvaluatingJavaScriptFromString("(function(){ return 'hel");
    webView.stringByEvaluatingJavaScriptFromString("new Exception('asdf')");
    webView.stringByEvaluatingJavaScriptFromString("throw new Exception('asdf')");

    auto err = webView.getMainDocumentError();
    if (err.length() > 0) {
      cerr << "test_webview failed: " << err << endl;
      return 1;
    }
    return 0;
}
