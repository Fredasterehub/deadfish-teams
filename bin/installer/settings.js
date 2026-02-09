'use strict';

const fs = require('node:fs');
const path = require('node:path');

const NAMESPACE_KEY = 'deadfish_teams';
const MANAGED_SOURCE = 'deadfish-teams';
const MANAGED_FLAG = 'deadfish_teams';

const HOOK_SPECS = [
  { event: 'TaskCompleted', script: 'on-task-completed.sh' },
  { event: 'TeammateIdle', script: 'on-teammate-idle.sh' },
  { event: 'SubagentStop', script: 'on-subagent-stop.sh' },
];

function assertNonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`Invalid ${label}: expected non-empty string`);
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
}

function shellDoubleQuote(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function buildHookCommand(pluginRoot, scriptName) {
  const escapedRoot = shellDoubleQuote(pluginRoot);
  const escapedScript = shellDoubleQuote(path.join(pluginRoot, 'hooks', 'scripts', scriptName));
  return `DEADFISH_PLUGIN_ROOT=\"${escapedRoot}\" bash \"${escapedScript}\"`;
}

function ensureObjectOrThrow(container, keyPath) {
  if (!isPlainObject(container)) {
    throw new Error(
      `settings.json schema conflict: '${keyPath}' must be an object. ` +
        `Fix '${keyPath}' and rerun install.`
    );
  }
}

function readSettings(settingsPath) {
  if (!fs.existsSync(settingsPath)) {
    return { existed: false, settings: {} };
  }

  const raw = fs.readFileSync(settingsPath, 'utf8');
  if (raw.trim() === '') {
    return { existed: true, settings: {} };
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new Error(
      `Failed to parse ${settingsPath}: ${error.message}. ` +
        'Fix invalid JSON and rerun install.'
    );
  }

  if (!isPlainObject(parsed)) {
    throw new Error(
      `settings.json schema conflict: root must be an object, got ${typeof parsed}.`
    );
  }

  return { existed: true, settings: parsed };
}

function ensureBackup(settingsPath, backupDir, dryRun) {
  if (!fs.existsSync(settingsPath) || dryRun) {
    return;
  }

  fs.mkdirSync(backupDir, { recursive: true });

  const baseName = path.basename(settingsPath);
  let targetPath = path.join(backupDir, baseName);
  let suffix = 1;
  while (fs.existsSync(targetPath)) {
    targetPath = path.join(backupDir, `${baseName}.${suffix}`);
    suffix += 1;
  }

  fs.copyFileSync(settingsPath, targetPath);
}

function isManagedHookEntry(entry, expectedCommands) {
  if (!isPlainObject(entry)) {
    return false;
  }

  if (entry[MANAGED_FLAG] === true) {
    return true;
  }

  if (entry.source !== MANAGED_SOURCE) {
    return false;
  }

  if (!Array.isArray(entry.hooks)) {
    return false;
  }

  return entry.hooks.some((hook) => {
    if (!isPlainObject(hook) || hook.type !== 'command' || typeof hook.command !== 'string') {
      return false;
    }
    return expectedCommands.has(hook.command);
  });
}

function buildManagedEntry(pluginRoot, eventName, command) {
  return {
    source: MANAGED_SOURCE,
    [MANAGED_FLAG]: true,
    plugin_root: pluginRoot,
    event: eventName,
    hooks: [
      {
        type: 'command',
        command,
      },
    ],
  };
}

function buildNamespaceBlob(pluginRoot, commandsByEvent) {
  return {
    source: MANAGED_SOURCE,
    schema_version: 1,
    plugin_root: pluginRoot,
    hooks_json_path: path.join(pluginRoot, 'hooks', 'hooks.json'),
    managed_events: HOOK_SPECS.map((spec) => spec.event),
    managed_commands: commandsByEvent,
  };
}

function normalizeSettingsForRegister(settings, pluginRoot) {
  const next = cloneJson(settings);

  if (Object.prototype.hasOwnProperty.call(next, NAMESPACE_KEY)) {
    ensureObjectOrThrow(next[NAMESPACE_KEY], NAMESPACE_KEY);
  }

  if (Object.prototype.hasOwnProperty.call(next, 'hooks')) {
    ensureObjectOrThrow(next.hooks, 'hooks');
  } else {
    next.hooks = {};
  }

  const commandsByEvent = {};
  const expectedCommands = new Set();
  for (const spec of HOOK_SPECS) {
    const command = buildHookCommand(pluginRoot, spec.script);
    commandsByEvent[spec.event] = command;
    expectedCommands.add(command);
  }

  for (const spec of HOOK_SPECS) {
    const eventName = spec.event;
    const command = commandsByEvent[eventName];

    const existing = next.hooks[eventName];
    if (existing === undefined) {
      next.hooks[eventName] = [];
    }

    if (!Array.isArray(next.hooks[eventName])) {
      throw new Error(
        `settings.json schema conflict: hooks.${eventName} must be an array. ` +
          `Fix hooks.${eventName} and rerun install.`
      );
    }

    const retained = next.hooks[eventName].filter((entry) => !isManagedHookEntry(entry, expectedCommands));
    retained.push(buildManagedEntry(pluginRoot, eventName, command));
    next.hooks[eventName] = retained;
  }

  next[NAMESPACE_KEY] = buildNamespaceBlob(pluginRoot, commandsByEvent);

  return next;
}

function normalizeSettingsForUnregister(settings, pluginRoot) {
  const next = cloneJson(settings);
  let changed = false;
  let removedManagedHooks = false;

  const namespace = isPlainObject(next[NAMESPACE_KEY]) ? next[NAMESPACE_KEY] : null;
  const commandsByEvent = isPlainObject(namespace && namespace.managed_commands)
    ? namespace.managed_commands
    : null;

  const expectedCommands = new Set();
  for (const spec of HOOK_SPECS) {
    expectedCommands.add(buildHookCommand(pluginRoot, spec.script));
    if (commandsByEvent && typeof commandsByEvent[spec.event] === 'string') {
      expectedCommands.add(commandsByEvent[spec.event]);
    }
  }

  if (Object.prototype.hasOwnProperty.call(next, 'hooks')) {
    ensureObjectOrThrow(next.hooks, 'hooks');

    for (const [eventName, entries] of Object.entries(next.hooks)) {
      if (!Array.isArray(entries)) {
        throw new Error(
          `settings.json schema conflict: hooks.${eventName} must be an array. ` +
            `Fix hooks.${eventName} and rerun uninstall.`
        );
      }

      const filtered = entries.filter((entry) => !isManagedHookEntry(entry, expectedCommands));
      if (filtered.length !== entries.length) {
        changed = true;
        removedManagedHooks = true;
      }

      if (filtered.length === 0) {
        delete next.hooks[eventName];
        if (entries.length > 0) {
          changed = true;
        }
      } else {
        next.hooks[eventName] = filtered;
      }
    }

    if (removedManagedHooks && Object.keys(next.hooks).length === 0) {
      delete next.hooks;
      changed = true;
    }
  }

  if (Object.prototype.hasOwnProperty.call(next, NAMESPACE_KEY)) {
    const candidate = next[NAMESPACE_KEY];
    if (!isPlainObject(candidate)) {
      throw new Error(
        `settings.json schema conflict: ${NAMESPACE_KEY} must be an object. ` +
          `Fix ${NAMESPACE_KEY} and rerun uninstall.`
      );
    }

    if (candidate.source === MANAGED_SOURCE || candidate.plugin_root === pluginRoot) {
      delete next[NAMESPACE_KEY];
      changed = true;
    }
  }

  return { next, changed };
}

function writeSettings(settingsPath, settingsObj, dryRun) {
  if (dryRun) {
    return;
  }

  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, `${JSON.stringify(settingsObj, null, 2)}\n`, 'utf8');
}

async function registerHooks({ claudeDir, pluginRoot, backupDir, dryRun }) {
  assertNonEmptyString(claudeDir, 'claudeDir');
  assertNonEmptyString(pluginRoot, 'pluginRoot');
  assertNonEmptyString(backupDir, 'backupDir');

  const settingsPath = path.join(claudeDir, 'settings.json');
  const { settings } = readSettings(settingsPath);

  const before = JSON.stringify(settings);
  const normalized = normalizeSettingsForRegister(settings, pluginRoot);
  const after = JSON.stringify(normalized);

  if (before === after) {
    return;
  }

  ensureBackup(settingsPath, backupDir, dryRun);
  writeSettings(settingsPath, normalized, dryRun);
}

async function unregisterHooks({ claudeDir, pluginRoot, backupDir, dryRun }) {
  assertNonEmptyString(claudeDir, 'claudeDir');
  assertNonEmptyString(pluginRoot, 'pluginRoot');
  assertNonEmptyString(backupDir, 'backupDir');

  const settingsPath = path.join(claudeDir, 'settings.json');
  if (!fs.existsSync(settingsPath)) {
    return;
  }

  const { settings } = readSettings(settingsPath);
  const { next, changed } = normalizeSettingsForUnregister(settings, pluginRoot);
  if (!changed) {
    return;
  }

  ensureBackup(settingsPath, backupDir, dryRun);
  writeSettings(settingsPath, next, dryRun);
}

module.exports = {
  registerHooks,
  unregisterHooks,
};
