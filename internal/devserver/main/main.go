package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"io"
	"io/ioutil"
	"bufio"
	"path/filepath"

	"github.com/bazelbuild/rules_typescript/internal/concatjs/concatjs"
	"github.com/bazelbuild/rules_typescript/internal/devserver/devserver"
)

var (
	port        = flag.Int("port", 5432, "server port to listen on")
	base        = flag.String("base", "", "server base (required, runfiles of the binary)")
	pkgs        = flag.String("packages", "", "root package(s) to serve, comma-separated")
	manifest    = flag.String("manifest", "", "sources manifest (.MF)")
	concat_scripts_manifest = flag.String("concat_scripts_manifest", "", "concast sources manifest (.MF)")
	node_modules_manifest = flag.String("node_modules_manifest", "", "node modules sources manifest (.MF)")
	servingPath = flag.String("serving_path", "/_/ts_scripts.js", "path to serve the combined sources at")
)

func main() {
	flag.Parse()

	if *base == "" || len(*pkgs) == 0 || (*manifest == "") || (*concat_scripts_manifest == "") || (*node_modules_manifest == "") {
		fmt.Fprintf(os.Stderr, "Required argument not set\n")
		os.Exit(1)
	}

	if _, err := os.Stat(*base); err != nil {
		fmt.Fprintf(os.Stderr, "Cannot read server base %s: %v\n", *base, err)
		os.Exit(1)
	}

	concatScriptsManifestPath := filepath.Join(*base, *concat_scripts_manifest)
	concat_scripts, err := manifestFiles(concatScriptsManifestPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read concat_scripts_manifest: %v\n", err)
		os.Exit(1)
	}

	nodeModulesManifestPath := filepath.Join(*base, *node_modules_manifest)
	node_modules_files, err := manifestFiles(nodeModulesManifestPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read node_modules_manifest: %v\n", err)
		os.Exit(1)
	}

	scripts := make([]string, 0, 100)

	requireJsPath := resolveNodeModulesFile(node_modules_files, "/node_modules/requirejs/require.js");
	if requireJsPath != "" {
		requireJs, err := loadScript(filepath.Join(*base, requireJsPath))
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to read requirejs script: %v\n", err)
		} else {
			scripts = append(scripts, requireJs)
		}
	} else {
		fmt.Fprintf(os.Stderr, "requirejs script not available\n")
	}

	livereloadUrl := os.Getenv("IBAZEL_LIVERELOAD_URL")
	re := regexp.MustCompile("^([a-zA-Z0-9]+)\\:\\/\\/([[a-zA-Z0-9\\.]+)\\:([0-9]+)")
	match := re.FindStringSubmatch(livereloadUrl)
	if match != nil && len(match) == 4 {
		port, err := strconv.ParseUint(match[3], 10, 16)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Cannot determine livereload port from IBAZEL_LIVERELOAD_URL")
		} else {
			livereloadScheme := match[1]
			livereloadHost := match[2]
			livereloadPort := uint16(port)
			livereloadJsPath := resolveNodeModulesFile(node_modules_files, "/node_modules/livereload/ext/livereload.js");
			if livereloadJsPath != "" {
				livereloadJs, err := loadScript(filepath.Join(*base, livereloadJsPath))
				if err != nil {
					fmt.Fprintf(os.Stderr, "Failed to read livereload script: %v\n", err)
				} else {
					scripts = append(scripts, fmt.Sprintf("\nwindow.LiveReloadOptions = { https: \"%s\" === \"https\", host: \"%s\", port: %d };", livereloadScheme, livereloadHost, livereloadPort))
					scripts = append(scripts, livereloadJs)
					fmt.Printf("Serving livereload script for port %s://%s:%d\n", livereloadScheme, livereloadHost, livereloadPort)
				}
			} else {
				fmt.Fprintf(os.Stderr, "livereload script not available\n")
			}
		}
	}

	profilerUrl := os.Getenv("IBAZEL_PROFILER_URL")
	match = re.FindStringSubmatch(profilerUrl)
	if match != nil && len(match) == 4 {
		port, err := strconv.ParseUint(match[3], 10, 16)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Cannot determine profiler port from IBAZEL_PROFILER_URL")
		} else {
			profilerScheme := match[1]
			profilerHost := match[2]
			profilerPort := uint16(port)
			scripts = append(scripts, fmt.Sprintf("\nwindow.IBazelProfilerOptions = { url: \"%s\", https: \"%s\" === \"https\", host: \"%s\", port: %d };", profilerUrl, profilerScheme, profilerHost, profilerPort))
		}
	}

	for _, v := range concat_scripts {
		js, err := loadScript(filepath.Join(*base, v))
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to read script %s: %v\n", v, err)
		} else {
			scripts = append(scripts, js)
		}
	}

	http.Handle(*servingPath, concatjs.ServeConcatenatedJS(*manifest, *base, scripts, nil /* realFileSystem */))
	pkgList := strings.Split(*pkgs, ",")
	http.HandleFunc("/", devserver.CreateFileHandler(*servingPath, *manifest, pkgList, *base))

	h, err := os.Hostname()
	if err != nil {
		h = "localhost"
	}

	fmt.Printf("Server listening on http://%s:%d/\n", h, *port)
	fmt.Fprintln(os.Stderr, http.ListenAndServe(fmt.Sprintf(":%d", *port), nil).Error())
	os.Exit(1)
}

func loadScript(path string) (string, error) {
	buf, err := ioutil.ReadFile(path)
	if err != nil {
		return "", err
	}
	return string(buf), nil
}

func resolveNodeModulesFile(node_modules_files []string, file string) string {
	for _, v := range node_modules_files {
		if strings.HasSuffix(v, file) {
			return v
		}
	}
	return ""
}

// manifestFiles parses a manifest, returning a list of the files in the manifest.
func manifestFiles(manifest string) ([]string, error) {
	f, err := os.Open(manifest)
	if err != nil {
		return nil, fmt.Errorf("could not read manifest %s: %s", manifest, err)
	}
	defer f.Close()
	return manifestFilesFromReader(f)
}

// manifestFilesFromReader is a helper for manifestFiles, split out for testing.
func manifestFilesFromReader(r io.Reader) ([]string, error) {
	var lines []string
	s := bufio.NewScanner(r)
	for s.Scan() {
		path := s.Text()
		if path == "" {
			continue
		}
		lines = append(lines, path)
	}
	if err := s.Err(); err != nil {
		return nil, err
	}

	return lines, nil
}
