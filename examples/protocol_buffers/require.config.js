// Shim the protobuf global symbol which was loaded by the bootstrap script
// so that it can be loaded with a named require statement.
define("protobufjs/minimal", () => protobuf);
