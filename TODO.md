- nested workspaces need to follow the example of internal/e2e/package_typescript_2.7 (and others), where package.json points to the built packages

- /tools/bash_stamp_vars.sh doesn't really work on windows so the version check fails

- e2e tests aren't being ran on windows so we don't know if they work