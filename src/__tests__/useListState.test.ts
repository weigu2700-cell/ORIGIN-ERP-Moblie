import { describe, it, expect, vi } from 'vitest'
import { useListState } from '@/shared/composables/useListState'

function createFetch(
  records: unknown[],
  total: number,
  shouldThrow = false,
) {
  return vi.fn(
    () =>
      shouldThrow
        ? Promise.reject(new Error('Network error'))
        : Promise.resolve({ records, total }),
  )
}

describe('useListState', () => {
  it('should start with idle status', () => {
    const fetch = createFetch([], 0)
    const state = useListState({ pageSize: 10, fetchPage: fetch })

    expect(state.status.value).toBe('idle')
    expect(state.isEmpty.value).toBe(false)
    expect(state.isInitialLoading.value).toBe(false)
    expect(state.list.value).toEqual([])
    expect(state.total.value).toBe(0)
  })

  it('should load first page and update status to ready', async () => {
    const fetch = createFetch([{ id: '1' }, { id: '2' }], 2)
    const state = useListState({ pageSize: 10, fetchPage: fetch })

    await state.loadPage(1)

    expect(state.status.value).toBe('ready')
    expect(state.list.value).toHaveLength(2)
    expect(state.total.value).toBe(2)
    expect(state.isEmpty.value).toBe(false)
    expect(state.finished.value).toBe(true)
    expect(fetch).toHaveBeenCalledWith(1, 10)
  })

  it('should set isEmpty when list is empty', async () => {
    const fetch = createFetch([], 0)
    const state = useListState({ pageSize: 10, fetchPage: fetch })

    await state.loadPage(1)

    expect(state.status.value).toBe('ready')
    expect(state.isEmpty.value).toBe(true)
    expect(state.finished.value).toBe(true)
  })

  it('should set error status on first load failure', async () => {
    const fetch = createFetch([], 0, true)
    const state = useListState({ pageSize: 10, fetchPage: fetch })

    await state.loadPage(1)

    expect(state.status.value).toBe('error')
    expect(state.errorMessage.value).toBe('Network error')
    expect(state.list.value).toEqual([])
  })

  it('should concat records on loadMore', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce({ records: [{ id: '1' }], total: 3 })
      .mockResolvedValueOnce({ records: [{ id: '2' }, { id: '3' }], total: 3 })

    const state = useListState<{ id: string }>({ pageSize: 2, fetchPage: fetch })
    await state.loadPage(1)
    await state.loadMore()

    expect(state.list.value).toHaveLength(3)
    expect(state.finished.value).toBe(true)
    expect(fetch).toHaveBeenCalledTimes(2)
  })

  it('should not loadMore when finished', async () => {
    const fetch = createFetch([{ id: '1' }], 1)
    const state = useListState({ pageSize: 10, fetchPage: fetch })

    await state.loadPage(1)
    await state.loadMore()

    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it('should not loadMore when loading', async () => {
    const fetch = vi
      .fn()
      .mockImplementation(
        () =>
          new Promise((resolve) =>
            setTimeout(() => resolve({ records: [{ id: '1' }], total: 2 }), 50),
          ),
      )

    const state = useListState({ pageSize: 1, fetchPage: fetch })

    const p1 = state.loadPage(1)
    const p2 = state.loadMore()

    await Promise.all([p1, p2])

    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it('should reset all state', async () => {
    const fetch = createFetch([{ id: '1' }, { id: '2' }], 2)
    const state = useListState({ pageSize: 10, fetchPage: fetch })

    await state.loadPage(1)
    state.reset()

    expect(state.status.value).toBe('idle')
    expect(state.list.value).toEqual([])
    expect(state.total.value).toBe(0)
    expect(state.page.value).toBe(1)
  })

  it('should refresh by reloading page 1', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce({ records: [{ id: '1' }], total: 3 })
      .mockResolvedValueOnce({ records: [{ id: 'x' }, { id: 'y' }], total: 2 })

    const state = useListState<{ id: string }>({ pageSize: 2, fetchPage: fetch })
    await state.loadPage(1)
    await state.refresh()

    expect(state.list.value).toHaveLength(2)
    expect(state.list.value[0].id).toBe('x')
  })

  it('should call onError callback on fetch failure', async () => {
    const onError = vi.fn()
    const fetch = createFetch([], 0, true)
    const state = useListState({ pageSize: 10, fetchPage: fetch, onError })

    await state.loadPage(1)
    expect(onError).toHaveBeenCalledOnce()
  })
})
describe('latest filter wins', () => {
  it('lets a scan refresh replace a pending initial request', async () => {
    let resolveOld!: (value: { records: string[]; total: number }) => void;
    const fetchPage = vi.fn()
      .mockImplementationOnce(() => new Promise((resolve) => { resolveOld = resolve; }))
      .mockResolvedValueOnce({ records: ['scanned'], total: 1 });
    const state = useListState<string>({ fetchPage });
    const old = state.loadPage(1);
    await state.refresh();
    resolveOld({ records: ['old'], total: 1 });
    await old;
    expect(state.list.value).toEqual(['scanned']);
    expect(state.loading.value).toBe(false);
  });
});
