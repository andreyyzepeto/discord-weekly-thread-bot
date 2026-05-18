import fs from "node:fs";
import path from "node:path";

const INSTANCES_DIR_NAME = "instances";
const INSTANCE_REGISTRY_FILE_NAME = "instances.json";

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string" && item.length > 0);
}

export function getAppRootDir(): string {
  return path.resolve(__dirname, "..");
}

export function getInstancesDir(appRootDir: string): string {
  return path.join(appRootDir, INSTANCES_DIR_NAME);
}

export function getInstanceRegistryFile(appRootDir: string): string {
  return path.join(getInstancesDir(appRootDir), INSTANCE_REGISTRY_FILE_NAME);
}

export function listInstanceNames(appRootDir: string): string[] {
  const instancesDir = getInstancesDir(appRootDir);
  const registryFile = getInstanceRegistryFile(appRootDir);

  try {
    const registry = JSON.parse(fs.readFileSync(registryFile, "utf8")) as unknown;
    if (isStringArray(registry)) {
      return [...new Set(registry)].sort();
    }
  } catch {
    // Fall back to directory inspection when the registry file does not exist yet.
  }

  if (!fs.existsSync(instancesDir)) {
    return [];
  }

  return fs
    .readdirSync(instancesDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .filter((name) => fs.existsSync(path.join(instancesDir, name, ".env")))
    .sort();
}

export function getInstanceDir(appRootDir: string, instanceName: string): string {
  return path.join(getInstancesDir(appRootDir), instanceName);
}

export function getInstanceEnvFile(appRootDir: string, instanceName: string): string {
  return path.join(getInstanceDir(appRootDir, instanceName), ".env");
}
