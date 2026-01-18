const queuePage = new Map<string, number>();

export function getQueuePage(userId: string) {
  return queuePage.get(userId) ?? 0;
}

export function setQueuePage(userId: string, page: number) {
  queuePage.set(userId, Math.max(0, page));
}
