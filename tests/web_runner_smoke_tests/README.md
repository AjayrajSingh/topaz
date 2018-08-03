# `web_runner_smoke_tests`

This is a black box smoke test for whether the web runner in a given system is
capable of performing basic operations.

This currently tests if launching a component with an HTTP URL triggers an HTTP
GET for the main resource, and if an HTML response with an <img> tag triggers a
subresource load for the image.
