const fs = require("node:fs/promises");
const { createHash } = require("node:crypto");

async function hashFile(filePath) {
  const data = await fs.readFile(filePath);
  return createHash("sha256").update(data).digest("hex");
}

module.exports = {
  hashFile,
};
