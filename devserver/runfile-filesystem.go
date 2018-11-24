package main

import (
	"io/ioutil"
	"os"
	"time"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

// RunfileFileSystem implements FileSystem type from concatjs.
type RunfileFileSystem struct {}

func (fs *RunfileFileSystem) StatMtime(filename string) (time.Time, error) {
	s, err := os.Stat(filename)
	if err != nil {
		return time.Time{}, err
	}
	return s.ModTime(), nil
}

func (fs *RunfileFileSystem) ReadFile(filename string) ([]byte, error) {
	return ioutil.ReadFile(filename)
}

func (fs *RunfileFileSystem) ResolvePath(root string, file string) (string, error) {
	return bazel.Runfile(file)
}