package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/bazelbuild/rules_typescript/internal/concatjs"
)

var (
	port        = flag.Int("port", 5432, "server port to listen on")
	base        = flag.String("base", "", "server base (required, runfiles of the binary)")
	pkgs        = flag.String("packages", "", "root package(s) to serve, comma-separated")
	manifest    = flag.String("manifest", "", "sources manifest (.MF)")
	servingPath = flag.String("serving_path", "/_/ts_scripts.js", "path to serve the combined sources at")
)

type customNotFoundResponseWriter struct {
	http.ResponseWriter

	request  *http.Request
	notFound http.HandlerFunc
	has404   bool
	hasWrite bool
}

// Write implements http.ResponseWriter.Write.
func (w *customNotFoundResponseWriter) Write(b []byte) (int, error) {
	w.hasWrite = true
	if w.has404 {
		// We have already written the not found response, so drop this one.
		return len(b), nil
	}
	return w.ResponseWriter.Write(b)
}

// WriteHeader implements http.ResponseWriter.WriteHeader.
func (w *customNotFoundResponseWriter) WriteHeader(code int) {
	if code != http.StatusNotFound || w.hasWrite {
		// We only intercept not found statuses. We also don't intercept statuses written after the
		// first write as these are an error and should be handled by the default ResponseWriter.
		w.ResponseWriter.WriteHeader(code)
		return
	}

	// WriteHeader writes out the entire header (including content type) and only the first call
	// will succeed. Therefore, if we want the correct content type set, we must set it here.
	w.Header().Del("Content-Type")
	w.Header().Add("Content-Type", "text/html; charset=utf-8")
	w.ResponseWriter.WriteHeader(code)
	w.has404 = true

	// We have already written the header, so drop any calls to WriteHeader made by the not found
	// handler. These additional calls are expected, and if passed through, would cause the base
	// ResponseWriter to unnecessarily spam the error log.
	w.notFound(&headerSuppressorResponseWriter{w.ResponseWriter}, w.request)
	w.hasWrite = true
}

type headerSuppressorResponseWriter struct {
	http.ResponseWriter
}

// WriteHeader implements http.ResponseWriter.WriteHeader.
func (w *headerSuppressorResponseWriter) WriteHeader(code int) {}

func createFileHandler(servingPath, manifest string, pkgs []string, base string) http.HandlerFunc {
	pkgPaths := chainedDir{}
	for _, pkg := range pkgs {
		path := filepath.Join(base, pkg)
		if _, err := os.Stat(path); err != nil {
			fmt.Fprintf(os.Stderr, "Cannot read server root package at %s: %v\n", path, err)
			os.Exit(1)
		}
		pkgPaths = append(pkgPaths, http.Dir(path))
	}
	pkgPaths = append(pkgPaths, http.Dir(base))

	fileHandler := http.FileServer(pkgPaths).ServeHTTP

	// defaultIndex is not cached, so that a user's edits will be reflected.
	defaultIndex := filepath.Join(base, pkgs[0], "index.html")

	// indexHandler serves an index.html if present, or exits if it is not found
	indexHandler := func(w http.ResponseWriter, r *http.Request) {
		if _, err := os.Stat(defaultIndex); err == nil {
			http.ServeFile(w, r, defaultIndex)
			return
		}
		log.Fatal("No index.html file found at " + defaultIndex)
	}

	// Serve a custom index.html so as to override the default directory listing
	// from http.FileServer when no index.html file present.
	indexOnNotFoundHandler := func(writer http.ResponseWriter, request *http.Request) {
		// The browser can't tell the difference between different source checkouts or different devserver
		// instances, so it may mistakenly cache static files (including templates) using versions from
		// old instances if they haven't been modified more recently. To prevent this, we force no-cache
		// on all static files.
		writer.Header().Add("Cache-Control", "no-cache, no-store, must-revalidate")
		writer.Header().Add("Pragma", "no-cache")
		writer.Header().Add("Expires", "0")
		// Add gzip headers if serving .gz files.
		if strings.HasSuffix(request.URL.EscapedPath(), ".gz") {
			writer.Header().Add("Content-Encoding", "gzip")
		}

		if request.URL.Path == "/" {
			indexHandler(writer, request)
			return
		}
		// When a file is not found, serve a 404 code but serve the index.html from above as its body.
		// This allows applications to use html5 routing and reload the page at /some/sub/path, but still
		// get their web app served.
		writer = &customNotFoundResponseWriter{ResponseWriter: writer, request: request, notFound: indexHandler}
		fileHandler(writer, request)
	}

	return indexOnNotFoundHandler
}

// chainedDir implements http.FileSystem by looking in the list of dirs one after each other.
type chainedDir []http.Dir

func (chain chainedDir) Open(name string) (http.File, error) {
	for _, dir := range chain {
		f, err := dir.Open(name)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return nil, err
		}

		// Do not return a directory, since FileServer will either:
		//  1) serve the index.html file -or-
		//  2) fall back to directory listings
		// In place of (2), we prefer to fall back to our index.html. We accomplish
		// this by lying to the FileServer that the directory doesn't exist.
		stat, err := f.Stat()
		if err != nil {
			return nil, err
		}
		if stat.IsDir() {
			// Make sure to close the previous file handle before moving to a different file.
			f.Close()
			indexName := filepath.Join(name, "index.html")
			f, err := dir.Open(indexName)
			if os.IsNotExist(err) {
				continue
			}
			return f, err
		}

		return f, nil
	}
	return nil, os.ErrNotExist
}

// realStatMtime returns the mtime for a file.
func realStatMtime(filename string) (time.Time, error) {
	s, err := os.Stat(filename)
	if err != nil {
		return time.Time{}, err
	}
	return s.ModTime(), nil
}

func realReadFile(filename string) ([]byte, error) {
	return ioutil.ReadFile(filename)
}

func main() {
	flag.Parse()

	pkgList := strings.Split(*pkgs, ",")
	http.Handle(*servingPath, concatjs.ServeConcatenatedJS(*manifest, *base, nil /* realFileSystem */))
	http.HandleFunc("/", createFileHandler(*servingPath, *manifest, pkgList, *base))

	h, err := os.Hostname()
	if err != nil {
		h = "localhost"
	}

	fmt.Printf("Server listening on http://%s:%d/\n", h, *port)
	fmt.Printf("JavaScript may be loaded from %s\n", *servingPath)
	fmt.Fprintln(os.Stderr, http.ListenAndServe(fmt.Sprintf(":%d", *port), nil).Error())
	os.Exit(1)
}
