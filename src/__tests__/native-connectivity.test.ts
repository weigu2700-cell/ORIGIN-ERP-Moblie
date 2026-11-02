import { afterEach, expect, it, vi } from 'vitest';
import { defineComponent, h } from 'vue';
import { mount } from '@vue/test-utils';
import { getOnlineStatus, useConnectivity } from '@/core/connectivity';

afterEach(() => {
  vi.unstubAllGlobals();
});
it('native offline is not overridden by navigator reporting online', async () => {
  vi.stubGlobal('uni', {
    getNetworkType: ({ success }: { success: (value: { networkType: string }) => void }) =>
      success({ networkType: 'none' }),
  });
  expect(await getOnlineStatus()).toBe(false);
});
it('native network probing works without navigator', async () => {
  vi.stubGlobal('navigator', undefined);
  vi.stubGlobal('uni', {
    getNetworkType: ({ success }: { success: (value: { networkType: string }) => void }) =>
      success({ networkType: 'wifi' }),
  });
  expect(await getOnlineStatus()).toBe(true);
});
it('registers one listener and removes the same listener on unmount', () => {
  const add = vi.fn();
  const remove = vi.fn();
  vi.stubGlobal('uni', {
    getNetworkType: ({ success }: { success: (value: { networkType: string }) => void }) =>
      success({ networkType: 'wifi' }),
    onNetworkStatusChange: add,
    offNetworkStatusChange: remove,
  });
  const wrapper = mount(
    defineComponent({
      setup() {
        const connection = useConnectivity();
        connection.startListening();
        connection.startListening();
        return () => h('div');
      },
    }),
  );
  expect(add).toHaveBeenCalledTimes(1);
  wrapper.unmount();
  expect(remove).toHaveBeenCalledWith(add.mock.calls[0][0]);
});
