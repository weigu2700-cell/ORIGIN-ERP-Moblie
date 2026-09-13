import { describe, it, expect } from 'vitest'
import { serializeQuery, generateSequenceId } from '@/core/api/request-sequence'

describe('request-sequence', () => {
  describe('serializeQuery', () => {
    it('should flatten nested objects into query string', () => {
      const result = serializeQuery({ pageNum: 1, pageSize: 20, status: 0 })
      expect(result).toBe('pageNum=1&pageSize=20&status=0')
    })

    it('should omit undefined values', () => {
      const result = serializeQuery({ pageNum: 1, name: undefined })
      expect(result).toBe('pageNum=1')
    })

    it('should omit null values', () => {
      const result = serializeQuery({ pageNum: 1, name: null })
      expect(result).toBe('pageNum=1')
    })

    it('should omit empty string values', () => {
      const result = serializeQuery({ pageNum: 1, keyword: '' })
      expect(result).toBe('pageNum=1')
    })

    it('should include zero as valid value', () => {
      const result = serializeQuery({ pageNum: 1, status: 0 })
      expect(result).toContain('status=0')
    })

    it('should include false as valid value', () => {
      const result = serializeQuery({ pageNum: 1, active: false } as any)
      expect(result).toContain('active=false')
    })

    it('should return empty string for empty object', () => {
      const result = serializeQuery({})
      expect(result).toBe('')
    })

    it('should handle Long/EntityId string values', () => {
      const result = serializeQuery({
        pageNum: 1,
        warehouseId: '1234567890123456789',
      })
      expect(result).toBe('pageNum=1&warehouseId=1234567890123456789')
    })
  })

  describe('generateSequenceId', () => {
    it('should generate incrementing IDs', () => {
      const id1 = generateSequenceId()
      const id2 = generateSequenceId()
      expect(id2).toBeGreaterThan(id1)
    })

    it('should generate positive numbers', () => {
      const id = generateSequenceId()
      expect(id).toBeGreaterThan(0)
    })
  })
})