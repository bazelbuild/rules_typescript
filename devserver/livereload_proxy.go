// Main package that provides a command line interface for starting a Bazel devserver
// using Bazel runfile resolution and ConcatJS for in-memory bundling of specified AMD files.
package main

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
)

// setupLivereloadProxy sets up two HTTP url handlers in order to expose the  livereload
// script and websocket endpoint through a specific configurable URL. This is helpful
// as "ibazel" sets up the livereload server on a unpredictable port and developers need
// a predictable/configurable endpoint where the livereload logic is served (especially
// if concatjs bundles are not used and the livereloading script cannot be inlined automatically)
func setupLivereloadProxy(scriptUrl string, ibazelScriptUrl string) error {
	// Parse the ibazel script URL in order to construct URLs that resolve to
	// the websocket endpoint and livereload server host.
	ibazelWebsocketUrl, err := url.Parse(ibazelScriptUrl)
	if err != nil {
		return fmt.Errorf("could not parse ibazel livereload url: %s", ibazelScriptUrl)
	}
	// this always resolves to the ibazel websocket URL. Read more about this:
	// https://github.com/jaschaephraim/lrserver#lrserver-livereload-server-for-go
	ibazelWebsocketUrl.Path = "/livereload"

	// Clone the ibazel livereload websocket URL and build a URL that just resolves to
	// the  livereload server host. This can be used to instantiate the reverse proxy.
	livereloadServerUrl := *ibazelWebsocketUrl;
	livereloadServerUrl.Path = ""

	// Build a reverse proxy resolving to the ibazel livereload server.
	reverseProxy := httputil.NewSingleHostReverseProxy(&livereloadServerUrl)

	// we always need a handler for "/livereload" as the livereload script always establishes
	// a websocket connection to that URL. This is not configurable.
	// 	// https://github.com/jaschaephraim/lrserver#lrserver-livereload-server-for-go
	http.Handle("/livereload", createHttpForwardHandler(reverseProxy, ibazelWebsocketUrl.String()))
	http.Handle(scriptUrl, createHttpForwardHandler(reverseProxy, ibazelScriptUrl))

	return nil
}

// createHttpForwardHandler creates an http handler that forwards all requests to a specific
// target url through a specified reverse proxy.
func createHttpForwardHandler(proxy *httputil.ReverseProxy, targetUrl string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		proxyRequest, err := http.NewRequest(r.Method, targetUrl, r.Body)
		if err != nil {
			http.Error(w, "Could not create forwarded request.", 500)
			return
		}
		copyRequestHeaders(r, proxyRequest)
		proxy.ServeHTTP(w, proxyRequest)
	})
}

// copyRequestHeaders copies all HTTP headers from a given request to another.
func copyRequestHeaders(originalRequest *http.Request, newRequest *http.Request) {
	for name, value := range originalRequest.Header {
		newRequest.Header.Set(name, value[0])
	}
}