const fs = require("node:fs/promises");
const path = require("node:path");

const { hashFile } = require("./hash");

const INSTALL_META_DIR = ".deadfish-install";
const MANIFEST_REL_PATH = path.join(INSTALL_META_DIR, "manifest.json");
const BACKUPS_REL_DIR = path.join(INSTALL_META_DIR, "backups");
const MANIFEST_VERSION = 1;

const PAYLOAD_ALLOWLIST = [
  "bin",
  "agents",
  "skills",
  "templates",
  "contracts",
  "hooks",
  "scripts",
  "docs",
  ".claude-plugin",
  "README.md",
  "CLAUDE.md",
  "requirements.txt",
];

const EXCLUDED_PATTERNS = [
  "__pycache__",
  ".pyc",
];

function logWarn(message) {
  console.warn(`[installer:copy] ${message}`);
}

function normalizeRelativePath(relativePath) {
  return relativePath.split(path.sep).join("/");
}

function ensureWithinRoot(root, relativePath) {
  if (typeof relativePath !== "string" || relativePath.trim() === "") {
    throw new Error("relative path must be a non-empty string");
  }

  const normalized = relativePath.replace(/\\/g, "/");
  if (path.posix.isAbsolute(normalized)) {
    throw new Error(`absolute path is not allowed: ${relativePath}`);
  }

  const resolvedRoot = path.resolve(root);
  const resolvedPath = path.resolve(resolvedRoot, normalized);
  if (resolvedPath !== resolvedRoot && !resolvedPath.startsWith(`${resolvedRoot}${path.sep}`)) {
    throw new Error(`path escapes plugin root: ${relativePath}`);
  }
  return resolvedPath;
}

function ensureAbsolutePathWithinRoot(root, targetPath) {
  const resolvedRoot = path.resolve(root);
  const resolvedTarget = path.resolve(targetPath);
  if (resolvedTarget === resolvedRoot) {
    return resolvedTarget;
  }
  if (!resolvedTarget.startsWith(`${resolvedRoot}${path.sep}`)) {
    throw new Error(`path escapes plugin root: ${targetPath}`);
  }
  return resolvedTarget;
}

async function safeLstat(filePath) {
  try {
    return await fs.lstat(filePath);
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

async function collectPayloadFiles(packageRoot) {
  const files = [];
  const skippedSymlinks = [];

  function isExcluded(name) {
    return EXCLUDED_PATTERNS.some((pattern) => name === pattern || name.endsWith(pattern));
  }

  async function walkDir(directoryPath) {
    const entries = await fs.readdir(directoryPath, { withFileTypes: true });
    for (const entry of entries) {
      if (isExcluded(entry.name)) {
        continue;
      }
      const entryPath = path.join(directoryPath, entry.name);
      if (entry.isSymbolicLink()) {
        skippedSymlinks.push(path.relative(packageRoot, entryPath));
        continue;
      }
      if (entry.isDirectory()) {
        await walkDir(entryPath);
        continue;
      }
      if (entry.isFile()) {
        files.push(path.relative(packageRoot, entryPath));
      }
    }
  }

  for (const allowlistedPath of PAYLOAD_ALLOWLIST) {
    const sourcePath = path.join(packageRoot, allowlistedPath);
    const sourceStat = await safeLstat(sourcePath);
    if (!sourceStat) {
      continue;
    }

    if (sourceStat.isSymbolicLink()) {
      skippedSymlinks.push(allowlistedPath);
      continue;
    }

    if (sourceStat.isDirectory()) {
      await walkDir(sourcePath);
      continue;
    }

    if (sourceStat.isFile()) {
      files.push(allowlistedPath);
    }
  }

  files.sort();
  return {
    files,
    skippedSymlinks: skippedSymlinks.sort(),
  };
}

async function readManifest(pluginRoot) {
  const manifestPath = path.join(pluginRoot, MANIFEST_REL_PATH);
  const manifestStat = await safeLstat(manifestPath);
  if (!manifestStat) {
    return null;
  }
  if (!manifestStat.isFile()) {
    throw new Error(`manifest path is not a regular file: ${manifestPath}`);
  }

  const raw = await fs.readFile(manifestPath, "utf8");
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new Error(`failed to parse manifest JSON: ${manifestPath}`);
  }

  const files = {};
  if (parsed && typeof parsed === "object" && parsed.files && typeof parsed.files === "object") {
    for (const [relativePath, meta] of Object.entries(parsed.files)) {
      if (!meta || typeof meta !== "object" || typeof meta.hash !== "string") {
        continue;
      }
      files[normalizeRelativePath(relativePath)] = {
        hash: meta.hash,
      };
    }
  }

  return {
    path: manifestPath,
    parsed,
    files,
  };
}

async function writeManifest(pluginRoot, manifest, dryRun) {
  if (dryRun) {
    return;
  }

  const installMetaDir = path.join(pluginRoot, INSTALL_META_DIR);
  await fs.mkdir(installMetaDir, { recursive: true });

  const manifestPath = path.join(pluginRoot, MANIFEST_REL_PATH);
  const tempPath = `${manifestPath}.tmp`;
  const serialized = `${JSON.stringify(manifest, null, 2)}\n`;
  await fs.writeFile(tempPath, serialized, "utf8");
  await fs.rename(tempPath, manifestPath);
}

async function backupFile({
  sourcePath,
  backupDir,
  relativePath,
  dryRun,
}) {
  if (dryRun) {
    return;
  }
  const backupPath = path.join(backupDir, relativePath);
  await fs.mkdir(path.dirname(backupPath), { recursive: true });
  await fs.copyFile(sourcePath, backupPath);
}

async function copyFileWithMode({
  sourcePath,
  destinationPath,
  sourceMode,
  dryRun,
}) {
  if (dryRun) {
    return;
  }
  await fs.mkdir(path.dirname(destinationPath), { recursive: true });
  await fs.copyFile(sourcePath, destinationPath);
  await fs.chmod(destinationPath, sourceMode & 0o777);
}

function buildManifest({ packageRoot, pluginRoot, files }) {
  const manifestFiles = {};
  for (const [relativePath, hash] of Object.entries(files)) {
    manifestFiles[relativePath] = { hash };
  }
  return {
    version: MANIFEST_VERSION,
    installed_at: new Date().toISOString(),
    package_root: packageRoot,
    plugin_root: pluginRoot,
    payload_allowlist: [...PAYLOAD_ALLOWLIST],
    backups_dir: BACKUPS_REL_DIR,
    files: manifestFiles,
  };
}

async function installPayload({
  packageRoot,
  pluginRoot,
  backupDir,
  dryRun,
}) {
  const copied = [];
  const backedUp = [];

  const resolvedPackageRoot = path.resolve(packageRoot);
  const resolvedPluginRoot = path.resolve(pluginRoot);
  const resolvedBackupDir = ensureAbsolutePathWithinRoot(pluginRoot, backupDir);

  const manifestState = await readManifest(resolvedPluginRoot);
  const previousHashes = manifestState ? manifestState.files : {};
  const sourceManifestFiles = {};

  const { files: payloadFiles, skippedSymlinks } = await collectPayloadFiles(resolvedPackageRoot);
  for (const skippedPath of skippedSymlinks) {
    logWarn(`skipping symlink in payload: ${skippedPath}`);
  }

  for (const relativePath of payloadFiles) {
    const normalizedRelativePath = normalizeRelativePath(relativePath);
    const sourcePath = path.join(resolvedPackageRoot, normalizedRelativePath);
    const destinationPath = ensureWithinRoot(resolvedPluginRoot, normalizedRelativePath);

    const sourceStat = await fs.lstat(sourcePath);
    if (!sourceStat.isFile()) {
      continue;
    }

    const destinationStat = await safeLstat(destinationPath);
    if (destinationStat && destinationStat.isSymbolicLink()) {
      logWarn(`skipping destination symlink: ${normalizedRelativePath}`);
      continue;
    }

    const previousEntry = previousHashes[normalizedRelativePath];
    if (destinationStat && destinationStat.isFile() && previousEntry && previousEntry.hash) {
      const currentDestHash = await hashFile(destinationPath);
      if (currentDestHash !== previousEntry.hash) {
        backedUp.push(normalizedRelativePath);
        await backupFile({
          sourcePath: destinationPath,
          backupDir: resolvedBackupDir,
          relativePath: normalizedRelativePath,
          dryRun: Boolean(dryRun),
        });
      }
    }

    copied.push(normalizedRelativePath);
    await copyFileWithMode({
      sourcePath,
      destinationPath,
      sourceMode: sourceStat.mode,
      dryRun: Boolean(dryRun),
    });

    sourceManifestFiles[normalizedRelativePath] = await hashFile(sourcePath);
  }

  const nextManifest = buildManifest({
    packageRoot: resolvedPackageRoot,
    pluginRoot: resolvedPluginRoot,
    files: sourceManifestFiles,
  });
  await writeManifest(resolvedPluginRoot, nextManifest, Boolean(dryRun));

  return {
    copied,
    backedUp,
  };
}

async function pruneEmptyParentDirs(pluginRoot, relativeFilePath, dryRun) {
  let currentDir = path.dirname(relativeFilePath);
  while (currentDir !== ".") {
    const absoluteDir = ensureWithinRoot(pluginRoot, currentDir);
    let entries;
    try {
      entries = await fs.readdir(absoluteDir);
    } catch (error) {
      if (error && error.code === "ENOENT") {
        currentDir = path.dirname(currentDir);
        continue;
      }
      throw error;
    }
    if (entries.length > 0) {
      return;
    }
    if (!dryRun) {
      await fs.rmdir(absoluteDir);
    }
    currentDir = path.dirname(currentDir);
  }
}

async function uninstallPayload({
  pluginRoot,
  backupDir,
  dryRun,
}) {
  void backupDir;

  const removed = [];
  const restored = [];
  const resolvedPluginRoot = path.resolve(pluginRoot);
  const manifestState = await readManifest(resolvedPluginRoot);
  if (!manifestState) {
    return {
      removed,
      restored,
    };
  }

  const filePaths = Object.keys(manifestState.files).sort();
  for (const relativePath of filePaths) {
    const normalizedRelativePath = normalizeRelativePath(relativePath);
    const targetPath = ensureWithinRoot(resolvedPluginRoot, normalizedRelativePath);
    const targetStat = await safeLstat(targetPath);
    if (!targetStat) {
      continue;
    }

    if (!targetStat.isFile() && !targetStat.isSymbolicLink()) {
      logWarn(`skipping non-file manifest entry during uninstall: ${normalizedRelativePath}`);
      continue;
    }

    removed.push(normalizedRelativePath);
    if (!dryRun) {
      await fs.rm(targetPath, { force: true });
    }
    await pruneEmptyParentDirs(resolvedPluginRoot, normalizedRelativePath, Boolean(dryRun));
  }

  const manifestPath = path.join(resolvedPluginRoot, MANIFEST_REL_PATH);
  const manifestStat = await safeLstat(manifestPath);
  if (manifestStat) {
    removed.push(normalizeRelativePath(MANIFEST_REL_PATH));
    if (!dryRun) {
      await fs.rm(manifestPath, { force: true });
    }
  }

  return {
    removed,
    restored,
  };
}

module.exports = {
  installPayload,
  uninstallPayload,
};
