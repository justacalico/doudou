import { useQueueStore } from "../stores/queueStore";

export function useQueue() {
  return useQueueStore((state) => ({
    items: state.items,
    enqueue: state.enqueue,
    resetQueue: state.resetQueue,
    refreshQueue: state.refreshQueue,
  }));
}
