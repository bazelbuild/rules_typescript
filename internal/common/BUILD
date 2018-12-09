package(default_visibility = ["//visibility:public"])

load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")

pkg_tar(
  name = "package",
  srcs = [
    "compilation.bzl",
    "json_marshal.bzl",
    "module_mappings.bzl",
    "tsconfig.bzl",
    "BUILD",
  ],
  package_dir = "common",
)
