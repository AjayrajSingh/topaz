const UglifyJsPlugin = require('uglifyjs-webpack-plugin')
const BannerPlugin = require('webpack').BannerPlugin;

module.exports = {
    entry: "./src/main.ts",
    output: {
        filename: "bundle.js",
        path: __dirname + "/dist",
    },

    devtool: "sourcemap",

    resolve: {
        extensions: [".ts", ".js", ".json",],
    },

    module: {
        rules: [
            // All files with a '.ts' extension will be handled by 'awesome-typescript-loader'.
            { test: /\.ts$/, loader: "awesome-typescript-loader" },

            // All output '.js' files will have any sourcemaps re-processed by 'source-map-loader'.
            { enforce: "pre", test: /\.js$/, loader: "source-map-loader" }
        ]
    },

    plugins: [
        new UglifyJsPlugin({
            sourceMap: true,
            uglifyOptions: {
                ie8: false,
                ecma: 5,
                safari10: true,
            },

        }),
        new BannerPlugin({
            banner:
                "Copyright 2018 The Fuchsia Authors. All rights reserved.\n" +
                "Use of this source code is governed by a BSD-style license that can be\n" +
                "found in the LICENSE file."
        }),
    ],


}
