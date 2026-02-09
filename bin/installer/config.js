'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');

const PLUGIN_ROOT_PLACEHOLDER = '__DEADFISH_PLUGIN_ROOT__';

/**
 * @typedef {Object} Options
 * @property {string=} scope
 * @property {string=} provider
 * @property {string=} teamMode
 * @property {string=} plannerModel
 * @property {string=} coderModel
 * @property {string=} qaModel
 * @property {boolean|string|number=} brownfieldDetection
 * @property {boolean|string|number=} brownfield
 * @property {string=} taskListIdPattern
 * @property {string=} version
 * @property {string=} packageVersion
 * @property {string=} installedAt
 */

/**
 * @param {unknown} value
 * @returns {string}
 */
function asString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

/**
 * @param {unknown} value
 * @returns {boolean}
 */
function asBoolean(value) {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  const normalized = String(value || '').trim().toLowerCase();
  if (['1', 'true', 'yes', 'y', 'on'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no', 'n', 'off'].includes(normalized)) {
    return false;
  }

  return false;
}

/**
 * YAML single-quote scalar escaping.
 * @param {unknown} value
 * @returns {string}
 */
function yamlScalar(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

/**
 * @param {Options} options
 * @returns {'anthropic-only'|'codex-mcp'|'hybrid'}
 */
function resolveProvider(options) {
  const provider = asString(options.provider).toLowerCase();
  if (provider === 'anthropic-only' || provider === 'codex-mcp' || provider === 'hybrid') {
    return provider;
  }

  return 'codex-mcp';
}

/**
 * @param {Options} options
 * @returns {'lite'|'full'}
 */
function resolveTeamMode(options) {
  const teamMode = asString(options.teamMode).toLowerCase();
  if (teamMode === 'full' || teamMode === 'lite') {
    return teamMode;
  }
  return 'lite';
}

/**
 * @param {'lite'|'full'} teamMode
 * @returns {string[]}
 */
function resolveTeamAgents(teamMode) {
  if (teamMode === 'full') {
    return [
      'discoverer',
      'brainstormer',
      'planner',
      'coder',
      'qa-reviewer',
      'conductor',
      'doc-keeper',
      'integrator',
    ];
  }
  return [
    'planner',
    'coder',
    'qa-reviewer',
    'integrator',
  ];
}

/**
 * @param {Options} options
 */
function resolveModels(options) {
  return {
    planner: asString(options.plannerModel) || 'gpt-5.2',
    coder: asString(options.coderModel) || 'gpt-5.3-codex',
    qa: asString(options.qaModel) || 'gpt-5.3-codex',
  };
}

/**
 * @param {Options} options
 */
function resolveBrownfieldDetection(options) {
  if (Object.prototype.hasOwnProperty.call(options, 'brownfieldDetection')) {
    return asBoolean(options.brownfieldDetection);
  }
  if (Object.prototype.hasOwnProperty.call(options, 'brownfield')) {
    return asBoolean(options.brownfield);
  }

  return true;
}

/**
 * @param {Options} options
 * @returns {{ deadfishConfigYaml: string, mcpJson: string }}
 */
function renderConfig(options = {}) {
  const provider = resolveProvider(options);
  const teamMode = resolveTeamMode(options);
  const defaultAgents = resolveTeamAgents(teamMode);
  const models = resolveModels(options);

  const scope = asString(options.scope) || 'global';
  const installedAt = asString(options.installedAt) || new Date().toISOString();
  const taskListIdPattern = asString(options.taskListIdPattern) || 'deadfish-YYYYMMDD';
  const version =
    asString(options.version) || asString(options.packageVersion) || asString(process.env.npm_package_version);

  const yamlLines = [
    'install:',
    `  scope: ${yamlScalar(scope)}`,
    `  installed_at: ${yamlScalar(installedAt)}`,
  ];

  if (version) {
    yamlLines.push(`  version: ${yamlScalar(version)}`);
  }

  yamlLines.push(
    `  provider: ${yamlScalar(provider)}`,
    'team:',
    `  mode: ${yamlScalar(teamMode)}`,
    '  default_agents:'
  );
  for (const agentName of defaultAgents) {
    yamlLines.push(`    - ${yamlScalar(agentName)}`);
  }

  yamlLines.push(
    'models:',
    `  planner: ${yamlScalar(models.planner)}`,
    `  coder: ${yamlScalar(models.coder)}`,
    `  qa: ${yamlScalar(models.qa)}`,
    'features:',
    `  brownfield_detection: ${resolveBrownfieldDetection(options) ? 'true' : 'false'}`,
    `task_list_id_pattern: ${yamlScalar(taskListIdPattern)}`,
    `plugin_root: ${yamlScalar(PLUGIN_ROOT_PLACEHOLDER)}`,
  );

  let mcpObj;
  if (provider === 'anthropic-only') {
    // Chosen rule: always emit a deterministic minimal .mcp.json for anthropic-only installs.
    mcpObj = { mcpServers: {} };
  } else {
    mcpObj = {
      mcpServers: {
        'codex-planner': {
          command: 'codex',
          args: ['mcp-server', '-m', models.planner, '-c', 'model_reasoning_effort="high"'],
        },
        'codex-coder': {
          command: 'codex',
          args: ['mcp-server', '-m', models.coder, '-c', 'model_reasoning_effort="high"'],
        },
      },
    };
  }

  return {
    deadfishConfigYaml: `${yamlLines.join('\n')}\n`,
    mcpJson: `${JSON.stringify(mcpObj, null, 2)}\n`,
  };
}

/**
 * @param {string} filePath
 * @returns {Promise<boolean>}
 */
async function fileExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

/**
 * @param {{ sourcePath: string, backupDir: string, dryRun: boolean, backedUp: string[] }} params
 */
async function backupIfPresent({ sourcePath, backupDir, dryRun, backedUp }) {
  if (!(await fileExists(sourcePath))) {
    return;
  }

  const backupPath = path.join(backupDir, path.basename(sourcePath));
  backedUp.push(backupPath);

  if (dryRun) {
    return;
  }

  await fs.mkdir(backupDir, { recursive: true });
  await fs.copyFile(sourcePath, backupPath);
}

/**
 * @param {{ pluginRoot: string, rendered: { deadfishConfigYaml: string, mcpJson: string }, backupDir: string, dryRun?: boolean }} args
 * @returns {Promise<{ written: string[], backedUp: string[], deadfishConfigYaml: string, mcpJson: string }>}
 */
async function writeConfig({ pluginRoot, rendered, backupDir, dryRun = false }) {
  if (!pluginRoot) {
    throw new Error('writeConfig requires pluginRoot');
  }
  if (!rendered || typeof rendered.deadfishConfigYaml !== 'string' || typeof rendered.mcpJson !== 'string') {
    throw new Error('writeConfig requires rendered.deadfishConfigYaml and rendered.mcpJson strings');
  }
  if (!backupDir) {
    throw new Error('writeConfig requires backupDir');
  }

  const deadfishConfigPath = path.join(pluginRoot, 'deadfish.config.yaml');
  const mcpPath = path.join(pluginRoot, '.mcp.json');

  const resolvedYaml = rendered.deadfishConfigYaml.replace(
    PLUGIN_ROOT_PLACEHOLDER,
    path.resolve(pluginRoot)
  );

  const backedUp = [];
  const written = [deadfishConfigPath, mcpPath];

  await backupIfPresent({ sourcePath: deadfishConfigPath, backupDir, dryRun, backedUp });
  await backupIfPresent({ sourcePath: mcpPath, backupDir, dryRun, backedUp });

  if (!dryRun) {
    await fs.mkdir(pluginRoot, { recursive: true });
    await fs.writeFile(deadfishConfigPath, resolvedYaml, 'utf8');
    await fs.writeFile(mcpPath, rendered.mcpJson, 'utf8');
  }

  return {
    written,
    backedUp,
    deadfishConfigYaml: resolvedYaml,
    mcpJson: rendered.mcpJson,
  };
}

module.exports = {
  renderConfig,
  writeConfig,
};
