#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { parseArgs, promptInteractive } = require("./installer/options");
const { getPackageRoot, resolveScope } = require("./installer/paths");

function usage() {
  return [
    "Usage:",
    "  deadfish-teams init",
    "  deadfish-teams --global [options]",
    "  deadfish-teams --local [options]",
    "",
    "Commands:",
    "  init                     Interactive setup when stdin is a TTY",
    "",
    "Flags:",
    "  --help                   Show this help",
    "  --global                 Install to ~/.claude/plugins/deadfish-teams",
    "  --local                  Install to ./.claude/plugins/deadfish-teams",
    "  --uninstall              Remove installed payload and unregister hooks",
    "  --dry-run                Print actions without writing files",
    "",
    "Overrides:",
    "  --provider <mode>        anthropic-only|codex-mcp|hybrid",
    "  --team-mode <mode>       lite|full (default: lite)",
    "  --planner-model <id>     Planner model id",
    "  --coder-model <id>       Coder model id",
    "  --qa-model <id>          QA model id",
    "  --brownfield true|false  Enable brownfield detection by default",
    "  --task-list-id-pattern <pattern>",
    "",
    "Examples:",
    "  deadfish-teams init",
    "  deadfish-teams --global",
    "  deadfish-teams --local --team-mode full",
    "  deadfish-teams --local --dry-run",
    "  deadfish-teams --global --provider hybrid --planner-model gpt-5.2"
  ].join("\n");
}

function formatTimestampForPath(date) {
  return date.toISOString().replace(/[-:]/g, "").replace(/\..+$/, "Z");
}

function createNoOpModules(missingModules) {
  const warnMissing = missingModules.length
    ? ` [dry-run fallback; missing modules: ${missingModules.join(", ")}]`
    : "";
  return {
    installPayload: async () => ({ copied: [], backedUp: [] }),
    uninstallPayload: async () => ({ removed: [], restored: [] }),
    renderConfig: () => ({ deadfishConfigYaml: "", mcpJson: "{}" }),
    writeConfig: async () => undefined,
    registerHooks: async () => undefined,
    unregisterHooks: async () => undefined,
    warnMissing
  };
}

function requireModule(modulePath) {
  try {
    return require(modulePath);
  } catch (error) {
    if (error && error.code === "MODULE_NOT_FOUND") {
      return null;
    }
    throw error;
  }
}

function loadInstallerModules({ dryRun }) {
  const copyModule = requireModule("./installer/copy");
  const configModule = requireModule("./installer/config");
  const settingsModule = requireModule("./installer/settings");

  const missing = [];
  if (!copyModule) {
    missing.push("copy.js");
  }
  if (!configModule) {
    missing.push("config.js");
  }
  if (!settingsModule) {
    missing.push("settings.js");
  }

  if (missing.length > 0 && !dryRun) {
    throw new Error(
      `Missing installer modules: ${missing.join(", ")}. Re-run with --dry-run or add missing modules.`
    );
  }
  if (missing.length > 0) {
    return createNoOpModules(missing);
  }

  return {
    installPayload: copyModule.installPayload,
    uninstallPayload: copyModule.uninstallPayload,
    renderConfig: configModule.renderConfig,
    writeConfig: configModule.writeConfig,
    registerHooks: settingsModule.registerHooks,
    unregisterHooks: settingsModule.unregisterHooks,
    warnMissing: ""
  };
}

function assertOptionContracts(options) {
  if (!options.scope) {
    throw new Error("Install scope is required. Use --global, --local, or run `deadfish-teams init` in a TTY.");
  }
}

async function runInstall(options) {
  const packageRoot = getPackageRoot();
  const cwd = process.cwd();
  const homedir = os.homedir();
  const { scope, claudeDir, pluginRoot } = resolveScope(options, cwd, homedir);

  const timestamp = formatTimestampForPath(new Date());
  const backupDir = path.join(pluginRoot, ".deadfish-install", "backups", timestamp);

  if (!options.dryRun) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const modules = loadInstallerModules({ dryRun: options.dryRun });
  if (modules.warnMissing) {
    console.warn(`[deadfish-teams]${modules.warnMissing}`);
  }

  if (options.uninstall) {
    const uninstallResult = await modules.uninstallPayload({
      pluginRoot,
      backupDir,
      dryRun: options.dryRun
    });
    await modules.unregisterHooks({
      claudeDir,
      pluginRoot,
      backupDir,
      dryRun: options.dryRun
    });
    console.log(
      JSON.stringify(
        {
          action: "uninstall",
          scope,
          claudeDir,
          pluginRoot,
          backupDir,
          removed: uninstallResult.removed || [],
          restored: uninstallResult.restored || [],
          dryRun: options.dryRun
        },
        null,
        2
      )
    );
    return;
  }

  const installResult = await modules.installPayload({
    packageRoot,
    pluginRoot,
    backupDir,
    dryRun: options.dryRun
  });
  const rendered = modules.renderConfig(options);
  await modules.writeConfig({
    pluginRoot,
    rendered,
    backupDir,
    dryRun: options.dryRun
  });
  await modules.registerHooks({
    claudeDir,
    pluginRoot,
    backupDir,
    dryRun: options.dryRun
  });

  console.log(
    JSON.stringify(
      {
        action: "install",
        scope,
        claudeDir,
        pluginRoot,
        backupDir,
        copied: installResult.copied || [],
        backedUp: installResult.backedUp || [],
        dryRun: options.dryRun
      },
      null,
      2
    )
  );
}

async function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2), process.env);
  } catch (error) {
    console.error(`[deadfish-teams] ${error.message}`);
    console.error(usage());
    process.exit(1);
  }

  if (options.help) {
    console.log(usage());
    process.exit(0);
  }

  let finalOptions = options;
  if (options.command === "init" && process.stdin.isTTY) {
    finalOptions = await promptInteractive(options);
  } else if (options.command === "init" && !process.stdin.isTTY) {
    assertOptionContracts(options);
  } else {
    assertOptionContracts(options);
  }

  await runInstall(finalOptions);
}

main().catch((error) => {
  console.error(`[deadfish-teams] ${error.message}`);
  process.exit(1);
});
