#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/deadfish-installer-test.XXXXXX")"

TEST_HOME="${TMP_ROOT}/home"
TEST_WORKSPACE="${TMP_ROOT}/workspace"
TEST_PROJECT="${TEST_WORKSPACE}/project"
HARNESS_ROOT="${TMP_ROOT}/harness"

INSTALL_ROOT="${REPO_ROOT}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "FATAL: required command not found: ${cmd}" >&2
    exit 2
  fi
}

print_header() {
  echo "installer test harness"
  echo "repo     : ${REPO_ROOT}"
  echo "tmp      : ${TMP_ROOT}"
  echo "home     : ${TEST_HOME}"
  echo "workspace: ${TEST_PROJECT}"
  echo
}

create_installer_harness() {
  mkdir -p "${HARNESS_ROOT}/bin/installer"

  cp "${REPO_ROOT}/bin/installer/settings.js" "${HARNESS_ROOT}/bin/installer/settings.js"

  cat > "${HARNESS_ROOT}/bin/install.js" <<'NODE'
#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { registerHooks, unregisterHooks } = require('./installer/settings');

const SOURCE_ROOT = process.env.DEADFISH_REPO_ROOT;
if (!SOURCE_ROOT) {
  console.error('DEADFISH_REPO_ROOT is required');
  process.exit(2);
}

const PAYLOAD_DIRS = [
  '.claude-plugin',
  'agents',
  'skills',
  'templates',
  'contracts',
  'hooks',
  'bin',
  'scripts',
];
const PAYLOAD_FILES = ['CLAUDE.md', 'README.md', 'requirements.txt'];

function parseArgs(argv) {
  const opts = {
    scope: 'local',
    dryRun: false,
    uninstall: false,
  };

  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') {
      console.log('usage: install.js [--local|--global] [--dry-run] [--uninstall]');
      process.exit(0);
    }
    if (arg === '--global') {
      opts.scope = 'global';
      continue;
    }
    if (arg === '--local') {
      opts.scope = 'local';
      continue;
    }
    if (arg === '--dry-run') {
      opts.dryRun = true;
      continue;
    }
    if (arg === '--uninstall') {
      opts.uninstall = true;
      continue;
    }
  }

  return opts;
}

function resolvePaths(scope) {
  const claudeDir = scope === 'global'
    ? path.join(os.homedir(), '.claude')
    : path.join(process.cwd(), '.claude');
  const pluginRoot = path.join(claudeDir, 'plugins', 'deadfish-teams');
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.join(pluginRoot, '.deadfish-install', 'backups', timestamp);
  return { claudeDir, pluginRoot, backupDir };
}

function readManifest(manifestPath) {
  if (!fs.existsSync(manifestPath)) {
    return { version: 1, files: {} };
  }
  const parsed = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (!parsed || typeof parsed !== 'object' || !parsed.files || typeof parsed.files !== 'object') {
    return { version: 1, files: {} };
  }
  return parsed;
}

function hashFile(filePath) {
  const data = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(data).digest('hex');
}

function walkFiles(rootDir) {
  const out = [];

  function walk(currentDir) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(currentDir, entry.name);
      if (entry.isSymbolicLink()) {
        continue;
      }
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (entry.isFile()) {
        out.push(full);
      }
    }
  }

  if (fs.existsSync(rootDir)) {
    walk(rootDir);
  }

  return out;
}

function backupIfModified({ dstPath, relPath, manifest, backupDir, dryRun }) {
  if (!fs.existsSync(dstPath)) {
    return;
  }

  const oldHash = manifest.files[relPath];
  if (!oldHash) {
    return;
  }

  const currentHash = hashFile(dstPath);
  if (currentHash === oldHash) {
    return;
  }

  const backupPath = path.join(backupDir, relPath);
  if (dryRun) {
    return;
  }

  fs.mkdirSync(path.dirname(backupPath), { recursive: true });
  fs.copyFileSync(dstPath, backupPath);
}

function copyFile({ srcPath, dstPath, relPath, manifest, backupDir, dryRun }) {
  backupIfModified({ dstPath, relPath, manifest, backupDir, dryRun });

  if (!dryRun) {
    fs.mkdirSync(path.dirname(dstPath), { recursive: true });
    fs.copyFileSync(srcPath, dstPath);
  }

  return hashFile(srcPath);
}

function buildConfigText({ scope, pluginRoot }) {
  return [
    'install:',
    `  scope: ${scope}`,
    `  plugin_root: ${pluginRoot}`,
    '',
  ].join('\n');
}

function installPayload({ pluginRoot, backupDir, dryRun, scope }) {
  const stateDir = path.join(pluginRoot, '.deadfish-install');
  const manifestPath = path.join(stateDir, 'manifest.json');
  const manifest = readManifest(manifestPath);
  const nextManifest = { version: 1, files: {} };

  for (const dir of PAYLOAD_DIRS) {
    const srcDir = path.join(SOURCE_ROOT, dir);
    if (!fs.existsSync(srcDir) || !fs.statSync(srcDir).isDirectory()) {
      continue;
    }

    for (const srcPath of walkFiles(srcDir)) {
      const relPath = path.relative(SOURCE_ROOT, srcPath);
      const dstPath = path.join(pluginRoot, relPath);
      nextManifest.files[relPath] = copyFile({ srcPath, dstPath, relPath, manifest, backupDir, dryRun });
    }
  }

  for (const fileName of PAYLOAD_FILES) {
    const srcPath = path.join(SOURCE_ROOT, fileName);
    if (!fs.existsSync(srcPath) || !fs.statSync(srcPath).isFile()) {
      continue;
    }
    const relPath = fileName;
    const dstPath = path.join(pluginRoot, relPath);
    nextManifest.files[relPath] = copyFile({ srcPath, dstPath, relPath, manifest, backupDir, dryRun });
  }

  const configPath = path.join(pluginRoot, 'deadfish.config.yaml');
  const mcpPath = path.join(pluginRoot, '.mcp.json');
  if (!dryRun) {
    fs.mkdirSync(pluginRoot, { recursive: true });
    fs.writeFileSync(configPath, buildConfigText({ scope, pluginRoot }), 'utf8');
    fs.writeFileSync(mcpPath, '{"mcpServers":{}}\n', 'utf8');
  }

  nextManifest.files['deadfish.config.yaml'] = crypto.createHash('sha256').update(buildConfigText({ scope, pluginRoot })).digest('hex');
  nextManifest.files['.mcp.json'] = crypto.createHash('sha256').update('{"mcpServers":{}}\n').digest('hex');

  if (!dryRun) {
    fs.mkdirSync(stateDir, { recursive: true });
    fs.writeFileSync(manifestPath, `${JSON.stringify(nextManifest, null, 2)}\n`, 'utf8');
  }
}

function uninstallPayload({ pluginRoot, dryRun }) {
  if (dryRun) {
    return;
  }
  if (fs.existsSync(pluginRoot)) {
    fs.rmSync(pluginRoot, { recursive: true, force: true });
  }
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const { claudeDir, pluginRoot, backupDir } = resolvePaths(opts.scope);

  if (opts.uninstall) {
    await unregisterHooks({ claudeDir, pluginRoot, backupDir, dryRun: opts.dryRun });
    uninstallPayload({ pluginRoot, dryRun: opts.dryRun });
    return;
  }

  installPayload({ pluginRoot, backupDir, dryRun: opts.dryRun, scope: opts.scope });
  await registerHooks({ claudeDir, pluginRoot, backupDir, dryRun: opts.dryRun });
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exit(1);
});
NODE

  chmod +x "${HARNESS_ROOT}/bin/install.js"
}

prepare_runtime_root() {
  if [[ -f "${REPO_ROOT}/bin/install.js" ]]; then
    INSTALL_ROOT="${REPO_ROOT}"
    return
  fi

  create_installer_harness
  INSTALL_ROOT="${HARNESS_ROOT}"
}

run_install() {
  local scope_flag="$1"
  shift || true

  (
    cd "${TEST_PROJECT}" || exit 1
    HOME="${TEST_HOME}" \
    DEADFISH_REPO_ROOT="${REPO_ROOT}" \
    node "${INSTALL_ROOT}/bin/install.js" "${scope_flag}" "$@"
  )
}

assert_exists() {
  local target="$1"
  if [[ ! -e "${target}" ]]; then
    echo "ASSERTION FAILED: expected path to exist: ${target}" >&2
    exit 1
  fi
}

assert_not_exists() {
  local target="$1"
  if [[ -e "${target}" ]]; then
    echo "ASSERTION FAILED: expected path to be absent: ${target}" >&2
    exit 1
  fi
}

assert_local_payload_copied() {
  local plugin_root="$1"

  assert_exists "${plugin_root}"
  assert_exists "${plugin_root}/agents"
  assert_exists "${plugin_root}/skills"
  assert_exists "${plugin_root}/templates"
  assert_exists "${plugin_root}/templates/track/decisions.md"
  assert_exists "${plugin_root}/templates/track/write-adr.md"
  assert_exists "${plugin_root}/templates/verify/conductor-reconcile.md"
  assert_exists "${plugin_root}/contracts"
  assert_exists "${plugin_root}/contracts/sentinel/v3/adr.v3.md"
  assert_exists "${plugin_root}/hooks"
  assert_exists "${plugin_root}/bin"
  assert_exists "${plugin_root}/scripts"
  assert_exists "${plugin_root}/.claude-plugin"
  assert_exists "${plugin_root}/README.md"
  assert_exists "${plugin_root}/CLAUDE.md"
  assert_exists "${plugin_root}/requirements.txt"
  assert_exists "${plugin_root}/.deadfish-install/manifest.json"
}

assert_backup_created_after_reinstall() {
  local plugin_root="$1"

  local count
  count="$(find "${plugin_root}/.deadfish-install/backups" -type f -name 'README.md' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${count}" -lt 1 ]]; then
    echo "ASSERTION FAILED: expected backup README.md after reinstall" >&2
    exit 1
  fi
}

main() {
  require_cmd bash
  require_cmd node
  require_cmd find

  mkdir -p "${TEST_HOME}" "${TEST_PROJECT}"

  print_header
  prepare_runtime_root

  local local_plugin_root="${TEST_PROJECT}/.claude/plugins/deadfish-teams"
  local global_plugin_root="${TEST_HOME}/.claude/plugins/deadfish-teams"

  echo "[1/7] local dry-run"
  run_install --local --dry-run >/dev/null

  echo "[2/7] global dry-run"
  run_install --global --dry-run >/dev/null

  echo "[3/7] local install"
  run_install --local >/dev/null
  assert_local_payload_copied "${local_plugin_root}"

  echo "[4/7] local reinstall backup check"
  echo "# operator local patch" >> "${local_plugin_root}/README.md"
  run_install --local >/dev/null
  assert_backup_created_after_reinstall "${local_plugin_root}"

  echo "[5/7] global install + settings check"
  run_install --global >/dev/null
  assert_exists "${global_plugin_root}"
  assert_exists "${TEST_HOME}/.claude/settings.json"
  grep -q '"deadfish_teams"' "${TEST_HOME}/.claude/settings.json"

  echo "[6/7] local uninstall"
  run_install --local --uninstall >/dev/null
  if [[ -e "${local_plugin_root}" ]]; then
    assert_not_exists "${local_plugin_root}/agents"
    assert_not_exists "${local_plugin_root}/skills"
    assert_not_exists "${local_plugin_root}/README.md"
  fi

  echo "[7/7] global uninstall"
  run_install --global --uninstall >/dev/null
  if [[ -e "${global_plugin_root}" ]]; then
    assert_not_exists "${global_plugin_root}/agents"
    assert_not_exists "${global_plugin_root}/skills"
    assert_not_exists "${global_plugin_root}/README.md"
  fi

  echo "PASS tests/test-installer.sh"
}

main "$@"
