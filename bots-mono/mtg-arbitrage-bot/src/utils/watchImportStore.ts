const pendingImports = new Map<string, string[]>();

export function setPendingImport(userId: string, names: string[]) {
  pendingImports.set(userId, names);
}

export function getPendingImport(userId: string): string[] | undefined {
  return pendingImports.get(userId);
}

export function clearPendingImport(userId: string) {
  pendingImports.delete(userId);
}
