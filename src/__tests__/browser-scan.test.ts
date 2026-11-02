import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
const decode = vi.hoisted(() => vi.fn());
vi.mock('@zxing/browser', () => ({
  BrowserMultiFormatReader: class {
    decodeFromStream = decode;
  },
}));
import { createBrowserScanner } from '@/core/scan/browser';

beforeEach(() => {
  vi.stubGlobal('window', { isSecureContext: true });
  decode.mockReset();
});
afterEach(() => {
  vi.unstubAllGlobals();
});

function setupCamera() {
  const track = { stop: vi.fn() };
  const stream = { getTracks: () => [track] };
  const getUserMedia = vi.fn().mockResolvedValue(stream);
  vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } });
  const video = { srcObject: stream } as unknown as HTMLVideoElement;
  return { track, stream, getUserMedia, video };
}

describe('browser scan camera lifecycle', () => {
  it('explains insecure deployment without asking for the camera', async () => {
    const { video, getUserMedia } = setupCamera();
    vi.stubGlobal('window', { isSecureContext: false });
    await expect(createBrowserScanner().start(video, vi.fn(), vi.fn())).rejects.toThrow('HTTPS');
    expect(getUserMedia).not.toHaveBeenCalled();
  });
  it('releases a stream granted after the page has closed', async () => {
    const { video, stream, track, getUserMedia } = setupCamera();
    let resolve!: (stream: unknown) => void;
    getUserMedia.mockReturnValue(
      new Promise((done) => {
        resolve = done;
      }),
    );
    const scanner = createBrowserScanner();
    const pending = scanner.start(video, vi.fn(), vi.fn());
    scanner.stop();
    resolve(stream);
    await pending;
    expect(track.stop).toHaveBeenCalled();
    expect(decode).not.toHaveBeenCalled();
  });
  it('releases the stream and preview when decoder startup fails', async () => {
    const { video, track } = setupCamera();
    decode.mockRejectedValue(new Error('failed'));
    await expect(createBrowserScanner().start(video, vi.fn(), vi.fn())).rejects.toThrow('failed');
    expect(track.stop).toHaveBeenCalled();
    expect(video.srcObject).toBeNull();
  });
  it('accepts one result then ignores duplicate decoder callbacks', async () => {
    const { video, track } = setupCamera();
    const controls = { stop: vi.fn() };
    let callback!: (result: unknown, error: unknown, controls: unknown) => void;
    decode.mockImplementation(async (_stream, _video, cb) => {
      callback = cb;
      return controls;
    });
    const scanner = createBrowserScanner();
    const result = vi.fn();
    await scanner.start(video, result, vi.fn());
    callback({ getText: () => '00123' }, undefined, controls);
    callback({ getText: () => '00123' }, undefined, controls);
    expect(result).toHaveBeenCalledTimes(1);
    expect(result).toHaveBeenCalledWith('00123');
    expect(track.stop).toHaveBeenCalled();
    expect(video.srcObject).toBeNull();
  });
});
