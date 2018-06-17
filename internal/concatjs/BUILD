load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

package(default_visibility = ["//internal:__subpackages__"])

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "source_tree",
    srcs = glob(["**/*"]),
)

go_library(
    name = "concatjs",
    srcs = ["concatjs.go"],
    importpath = "github.com/bazelbuild/rules_typescript/internal/concatjs/concatjs",
)

go_test(
    name = "concatjs_test",
    size = "small",
    srcs = ["concatjs_test.go"],
    # See https://github.com/bazelbuild/rules_go/issues/721
    importpath = "do_not_import",
    library = ":concatjs",
)
