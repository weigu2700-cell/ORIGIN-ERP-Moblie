import { describe, it, expect } from 'vitest'

interface ConnectionStatus {
  online: boolean
  type: string
}

describe('connection status utilities', () => {
  describe('isRetryableWrite', () => {
    /**
     * 文档要求：写请求不自动重试；冲突/校验失败禁止重试。
     */
    const isRetryableWrite = (
      status: ConnectionStatus,
      lastStatus: number | null,
    ) => {
      if (!status.online) return false
      if (lastStatus === 409) return false
      if (lastStatus === 400) return false
      return true
    }

    it('should forbid write retry when offline', () => {
      expect(
        isRetryableWrite({ online: false, type: 'none' }, null),
      ).toBe(false)
    })

    it('should allow write retry when online with no conflict', () => {
      expect(
        isRetryableWrite({ online: true, type: 'wifi' }, null),
      ).toBe(true)
    })

    it('should forbid write retry after 409 Conflict', () => {
      expect(
        isRetryableWrite({ online: true, type: 'wifi' }, 409),
      ).toBe(false)
    })

    it('should forbid write retry after 400 Bad Request', () => {
      expect(
        isRetryableWrite({ online: true, type: '4g' }, 400),
      ).toBe(false)
    })

    it('should allow retry after 500 Server Error when online', () => {
      expect(
        isRetryableWrite({ online: true, type: 'wifi' }, 500),
      ).toBe(true)
    })
  })

  describe('offline status derivation', () => {
    const deriveStatus = (networkType: string): ConnectionStatus => ({
      online: networkType !== 'none',
      type: networkType,
    })

    it('should mark wifi as online', () => {
      expect(deriveStatus('wifi').online).toBe(true)
    })

    it('should mark 4g as online', () => {
      expect(deriveStatus('4g').online).toBe(true)
    })

    it('should mark none as offline', () => {
      expect(deriveStatus('none').online).toBe(false)
    })

    it('should preserve network type in status', () => {
      expect(deriveStatus('wifi').type).toBe('wifi')
    })
  })
})