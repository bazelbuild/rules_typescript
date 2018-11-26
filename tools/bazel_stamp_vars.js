const execSync = require('child_process').execSync;
function _exec(str) {
  return execSync(str).toString().trim();
}

const BUILD_SCM_VERSION = _exec(`git describe --abbrev=7 --tags HEAD`);
console.log(`BUILD_SCM_VERSION ${BUILD_SCM_VERSION}`);
