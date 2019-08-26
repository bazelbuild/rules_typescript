package main

import (
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestLivereloadProxy (t *testing.T) {
	recorder := httptest.NewRecorder()
	scriptRequestForwarded := false
	websocketRequestForwarded := false
	livereloadServerHost := "localhost:1234"
	livereloadServerUrl := "http://" + livereloadServerHost

	livereloadServer := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Printf(r.URL.String())
		if r.URL.Path == "/livereload" {
			websocketRequestForwarded = true
		} else if r.URL.Path == "/livereload_1234.js" {
			scriptRequestForwarded = true
			w.Write([]byte("script content"))
		}
	}))

	listener, _ := net.Listen("tcp", livereloadServerHost)
	livereloadServer.Listener = listener
	livereloadServer.Start()

	defer livereloadServer.Close()

	// setup the livereload proxy handlers.
	err := setupLivereloadProxy("/my-livereload-script.js", livereloadServerUrl + "/livereload_1234.js")

	if err != nil {
		t.Fatal(err)
	}

	scriptRequest := httptest.NewRequest("GET", "/my-livereload-script.js", nil)
	wsRequest := httptest.NewRequest("GET", "/livereload", nil)

	http.DefaultServeMux.ServeHTTP(recorder, scriptRequest)
	http.DefaultServeMux.ServeHTTP(recorder, wsRequest)

	if recorder.Code != 200 {
		t.Errorf("Expected response status code to be 200, but got: %d", recorder.Code)
	}

	if scriptRequestForwarded == false {
		t.Errorf("Expected script request to get forwarded")
	}

	if websocketRequestForwarded == false {
		t.Errorf("Expected websocket request to get forwarded")
	}

	if recorder.Body.String() != "script content" {
		t.Errorf("Expected forwarded request to retrieve correct response")
	}
}