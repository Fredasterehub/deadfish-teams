const fs = require("fs");
const path = require("path");

function findUpWithPackageJson(startDir) {
  let cursor = startDir;
  while (true) {
    const packageJsonPath = path.join(cursor, "package.json");
    if (fs.existsSync(packageJsonPath)) {
      return cursor;
    }
    const parent = path.dirname(cursor);
    if (parent === cursor) {
      throw new Error(`Unable to locate package.json from ${startDir}`);
    }
    cursor = parent;
  }
}

/**
 * Find the folder containing package.json for this CLI.
 * Works whether executed from source checkout or npm cache paths.
 *
 * @returns {string}
 */
function getPackageRoot() {
  return findUpWithPackageJson(path.resolve(__dirname, "..", ".."));
}

/**
 * @param {{ scope?: "global"|"local"|null }} options
 * @param {string} cwd
 * @param {string} homedir
 * @returns {{ scope: "global"|"local", claudeDir: string, pluginRoot: string }}
 */
function resolveScope(options, cwd, homedir) {
  const scope = options.scope === "local" ? "local" : "global";
  const claudeDir = scope === "global" ? path.join(homedir, ".claude") : path.join(cwd, ".claude");
  const pluginRoot = path.join(claudeDir, "plugins", "deadfish-teams");
  return { scope, claudeDir, pluginRoot };
}

module.exports = {
  getPackageRoot,
  resolveScope
};
