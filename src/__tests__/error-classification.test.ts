import { describe, it, expect } from 'vitest'
import { classifyError, isRetryableError } from '@/core/api/errors'

describe('error classification', () => {
  describe('classifyError', () => {
    it('should classify 401 as unauthorized', () => {
      const error = { statusCode: 401 }
      const result = classifyError(error)
      expect(result.kind).toBe('unauthorized')
    })

    it('should classify 403 as forbidden', () => {
      const error = { statusCode: 403 }
      const result = classifyError(error)
      expect(result.kind).toBe('forbidden')
    })

    it('should classify 404 as notFound', () => {
      const error = { statusCode: 404 }
      const result = classifyError(error)
      expect(result.kind).toBe('notFound')
    })

    it('should classify 409 as conflict', () => {
      const error = { statusCode: 409 }
      const result = classifyError(error)
      expect(result.kind).toBe('conflict')
    })

    it('should classify 500 as server', () => {
      const error = { statusCode: 500 }
      const result = classifyError(error)
      expect(result.kind).toBe('server')
    })

    it('should classify 422 as validation', () => {
      const error = { statusCode: 422 }
      const result = classifyError(error)
      expect(result.kind).toBe('validation')
    })

    it('should classify unknown status as unknown', () => {
      const error = { statusCode: 418 }
      const result = classifyError(error)
      expect(result.kind).toBe('unknown')
    })

    it('should classify fetch failure as network', () => {
      const error = { message: 'Failed to fetch' }
      const result = classifyError(error)
      expect(result.kind).toBe('network')
    })

    it('should classify timeout error as timeout', () => {
      const error = { message: 'The request timed out' }
      const result = classifyError(error)
      expect(result.kind).toBe('timeout')
    })
  })

  describe('isRetryableError', () => {
    it('should allow retry for network error', () => {
      expect(isRetryableError('network')).toBe(true)
    })

    it('should allow retry for timeout', () => {
      expect(isRetryableError('timeout')).toBe(true)
    })

    it('should allow retry for server error', () => {
      expect(isRetryableError('server')).toBe(true)
    })

    it('should NOT retry for conflict (409)', () => {
      expect(isRetryableError('conflict')).toBe(false)
    })

    it('should NOT retry for forbidden (403)', () => {
      expect(isRetryableError('forbidden')).toBe(false)
    })

    it('should NOT retry for unauthorized (401)', () => {
      expect(isRetryableError('unauthorized')).toBe(false)
    })

    it('should NOT retry for validation (422)', () => {
      expect(isRetryableError('validation')).toBe(false)
    })
  })
})