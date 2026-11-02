import { BrowserMultiFormatReader, type IScannerControls } from '@zxing/browser';

/** Own the stream before decoder startup so leaving during a permission prompt cannot leak the camera. */
export function createBrowserScanner() {
  let generation = 0;
  let stream: MediaStream | undefined;
  let controls: IScannerControls | undefined;
  let video: HTMLVideoElement | undefined;

  function stop() {
    generation++;
    controls?.stop();
    controls = undefined;
    stream?.getTracks().forEach((track) => track.stop());
    stream = undefined;
    if (video) video.srcObject = null;
    video = undefined;
  }

  async function start(
    element: HTMLVideoElement,
    onResult: (value: string) => void,
    onError: (error: unknown) => void,
  ) {
    stop();
    const current = generation;
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
      throw new Error('相机扫码需要 HTTPS 或 localhost，请使用安全地址访问，或手动输入编码');
    }
    const acquired = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' } },
      audio: false,
    });
    if (current !== generation) {
      acquired.getTracks().forEach((track) => track.stop());
      return;
    }
    stream = acquired;
    video = element;
    try {
      const reader = new BrowserMultiFormatReader();
      const activeControls = await reader.decodeFromStream(
        acquired,
        element,
        (result, error, scannerControls) => {
          if (current !== generation) {
            scannerControls.stop();
            return;
          }
          if (result) {
            const value = result.getText();
            scannerControls.stop();
            stop();
            onResult(value);
          } else if (
            error &&
            !['NotFoundException', 'ChecksumException', 'FormatException'].includes(error.name)
          ) {
            stop();
            onError(error);
          }
        },
      );
      if (current !== generation) activeControls.stop();
      else controls = activeControls;
    } catch (error) {
      if (current === generation) stop();
      throw error;
    }
  }

  return { start, stop };
}
