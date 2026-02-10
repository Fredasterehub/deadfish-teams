const readline = require("readline/promises");

const DEFAULTS = Object.freeze({
  provider: "hybrid",
  teamMode: "full",
  plannerModel: "gpt-5.2",
  coderModel: "gpt-5.3-codex",
  qaModel: "gpt-5.3-codex",
  brownfield: true,
  taskListIdPattern: "deadfish-YYYYMMDD"
});

const PROVIDERS = new Set(["anthropic-only", "codex-mcp", "hybrid"]);
const TEAM_MODES = new Set(["lite", "full"]);
const LITE_MODE_WARNING = "Lite mode disables Conductor + Doc-keeper. Living docs will not auto-update. Drift detection disabled.";

/**
 * @typedef {Object} Options
 * @property {"init"|"install"} command
 * @property {"global"|"local"|null} scope
 * @property {"anthropic-only"|"codex-mcp"|"hybrid"} provider
 * @property {"lite"|"full"} teamMode
 * @property {string} plannerModel
 * @property {string} coderModel
 * @property {string} qaModel
 * @property {boolean} brownfield
 * @property {string} taskListIdPattern
 * @property {boolean} uninstall
 * @property {boolean} dryRun
 * @property {boolean} help
 */

function parseBool(value, flagName) {
  if (value === "true") {
    return true;
  }
  if (value === "false") {
    return false;
  }
  throw new Error(`Invalid value for ${flagName}: ${value} (expected true|false)`);
}

function parseScopeValue(value) {
  if (value === "global" || value === "local") {
    return value;
  }
  return null;
}

function requireValue(argv, index, flagName) {
  const value = argv[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${flagName}`);
  }
  return value;
}

/**
 * @param {string[]} argv
 * @param {NodeJS.ProcessEnv} env
 * @returns {Options}
 */
function parseArgs(argv, env) {
  const envScope = parseScopeValue(env.DEADFISH_INSTALL_SCOPE || "");
  let teamModeSetByFlag = false;
  /** @type {Options} */
  const options = {
    command: "install",
    scope: envScope,
    provider: env.DEADFISH_PROVIDER && PROVIDERS.has(env.DEADFISH_PROVIDER)
      ? env.DEADFISH_PROVIDER
      : DEFAULTS.provider,
    teamMode: env.DEADFISH_TEAM_MODE && TEAM_MODES.has(env.DEADFISH_TEAM_MODE)
      ? env.DEADFISH_TEAM_MODE
      : DEFAULTS.teamMode,
    plannerModel: env.DEADFISH_PLANNER_MODEL || DEFAULTS.plannerModel,
    coderModel: env.DEADFISH_CODER_MODEL || DEFAULTS.coderModel,
    qaModel: env.DEADFISH_QA_MODEL || DEFAULTS.qaModel,
    brownfield: env.DEADFISH_BROWNFIELD
      ? parseBool(env.DEADFISH_BROWNFIELD, "DEADFISH_BROWNFIELD")
      : DEFAULTS.brownfield,
    taskListIdPattern: env.DEADFISH_TASK_LIST_ID_PATTERN || DEFAULTS.taskListIdPattern,
    uninstall: false,
    dryRun: false,
    help: false
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "init") {
      options.command = "init";
      continue;
    }
    if (arg === "install") {
      options.command = "install";
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      options.help = true;
      continue;
    }
    if (arg === "--global") {
      if (options.scope === "local") {
        throw new Error("Cannot combine --global and --local");
      }
      options.scope = "global";
      continue;
    }
    if (arg === "--local") {
      if (options.scope === "global") {
        throw new Error("Cannot combine --global and --local");
      }
      options.scope = "local";
      continue;
    }
    if (arg === "--uninstall") {
      options.uninstall = true;
      continue;
    }
    if (arg === "--dry-run") {
      options.dryRun = true;
      continue;
    }
    if (arg === "--provider") {
      const value = requireValue(argv, i, "--provider");
      if (!PROVIDERS.has(value)) {
        throw new Error(
          `Invalid provider: ${value} (expected anthropic-only|codex-mcp|hybrid)`
        );
      }
      options.provider = value;
      i += 1;
      continue;
    }
    if (arg === "--team-mode") {
      const value = requireValue(argv, i, "--team-mode");
      if (!TEAM_MODES.has(value)) {
        throw new Error(
          `Invalid team mode: ${value} (expected lite|full)`
        );
      }
      options.teamMode = value;
      teamModeSetByFlag = true;
      i += 1;
      continue;
    }
    if (arg === "--planner-model") {
      options.plannerModel = requireValue(argv, i, "--planner-model");
      i += 1;
      continue;
    }
    if (arg === "--coder-model") {
      options.coderModel = requireValue(argv, i, "--coder-model");
      i += 1;
      continue;
    }
    if (arg === "--qa-model") {
      options.qaModel = requireValue(argv, i, "--qa-model");
      i += 1;
      continue;
    }
    if (arg === "--brownfield") {
      options.brownfield = parseBool(requireValue(argv, i, "--brownfield"), "--brownfield");
      i += 1;
      continue;
    }
    if (arg === "--task-list-id-pattern") {
      options.taskListIdPattern = requireValue(argv, i, "--task-list-id-pattern");
      i += 1;
      continue;
    }
    if (arg.startsWith("-")) {
      throw new Error(`Unknown flag: ${arg}`);
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (teamModeSetByFlag && options.teamMode === "lite") {
    console.warn(`WARNING: ${LITE_MODE_WARNING}`);
  }

  return options;
}

async function askChoice(rl, label, choices, defaultValue) {
  const hint = choices.join("/");
  const input = await rl.question(`${label} [${hint}] (default: ${defaultValue}): `);
  const value = input.trim() || defaultValue;
  if (!choices.includes(value)) {
    throw new Error(`Invalid choice for ${label}: ${value}`);
  }
  return value;
}

async function askText(rl, label, defaultValue) {
  const input = await rl.question(`${label} (default: ${defaultValue}): `);
  const value = input.trim();
  return value || defaultValue;
}

async function askYesNo(rl, label, defaultValue) {
  const defaultToken = defaultValue ? "y" : "n";
  const input = await rl.question(`${label} [y/n] (default: ${defaultToken}): `);
  const value = input.trim().toLowerCase();
  if (!value) {
    return defaultValue;
  }
  if (value === "y" || value === "yes") {
    return true;
  }
  if (value === "n" || value === "no") {
    return false;
  }
  throw new Error(`Invalid yes/no value: ${input}`);
}

/**
 * Prompt order is fixed by Round 4 overview:
 * 1) scope
 * 2) provider
 * 3) team mode
 * 4) planner/coder/qa models
 * 5) brownfield default
 * 6) task list id pattern
 *
 * @param {Options} partial
 * @returns {Promise<Options>}
 */
async function promptInteractive(partial) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  try {
    const scope = await askChoice(rl, "Install scope", ["global", "local"], partial.scope || "global");
    const provider = await askChoice(
      rl,
      "Provider routing",
      ["anthropic-only", "codex-mcp", "hybrid"],
      partial.provider || DEFAULTS.provider
    );
    const teamMode = await askChoice(
      rl,
      "Team mode",
      ["lite", "full"],
      partial.teamMode || DEFAULTS.teamMode
    );
    const plannerModel = await askText(rl, "Planner model id", partial.plannerModel || DEFAULTS.plannerModel);
    const coderModel = await askText(rl, "Coder model id", partial.coderModel || DEFAULTS.coderModel);
    const qaModel = await askText(rl, "QA model id", partial.qaModel || DEFAULTS.qaModel);
    const brownfield = await askYesNo(
      rl,
      "Enable brownfield detection by default",
      typeof partial.brownfield === "boolean" ? partial.brownfield : DEFAULTS.brownfield
    );
    const taskListIdPattern = await askText(
      rl,
      "Task list ID pattern",
      partial.taskListIdPattern || DEFAULTS.taskListIdPattern
    );

    return {
      ...partial,
      command: "init",
      scope,
      provider,
      teamMode,
      plannerModel,
      coderModel,
      qaModel,
      brownfield,
      taskListIdPattern
    };
  } finally {
    rl.close();
  }
}

module.exports = {
  DEFAULTS,
  parseArgs,
  promptInteractive
};
