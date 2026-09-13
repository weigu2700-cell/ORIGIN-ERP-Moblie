import { describe, it, expect } from 'vitest'
import {
  hasPermission,
  hasAllPermissions,
  hasAnyPermission,
  PERMISSION_CODES,
} from '@/core/auth/permission-registry'

describe('permission-registry', () => {
  const userPerms = [
    PERMISSION_CODES.inventoryList,
    PERMISSION_CODES.purchaseInboundList,
  ]

  describe('hasPermission', () => {
    it('should return true for a permission the user has', () => {
      expect(hasPermission(userPerms, PERMISSION_CODES.inventoryList)).toBe(true)
    })

    it('should return false for a permission the user lacks', () => {
      expect(hasPermission(userPerms, PERMISSION_CODES.productionPickingList)).toBe(
        false,
      )
    })

    it('should return false for empty user permissions', () => {
      expect(hasPermission([], PERMISSION_CODES.inventoryList)).toBe(false)
    })

    it('should handle wildcard permission', () => {
      expect(hasPermission(['*:*'], PERMISSION_CODES.inventoryList)).toBe(true)
    })
  })

  describe('hasAllPermissions', () => {
    it('should return true when user has all required permissions', () => {
      expect(
        hasAllPermissions(userPerms, [
          PERMISSION_CODES.inventoryList,
          PERMISSION_CODES.purchaseInboundList,
        ]),
      ).toBe(true)
    })

    it('should return false when user misses one permission', () => {
      expect(
        hasAllPermissions(userPerms, [
          PERMISSION_CODES.inventoryList,
          PERMISSION_CODES.productionPickingList,
        ]),
      ).toBe(false)
    })

    it('should return true for empty requirements', () => {
      expect(hasAllPermissions(userPerms, [])).toBe(true)
    })

    it('should handle wildcard', () => {
      expect(
        hasAllPermissions(['*:*'], [
          PERMISSION_CODES.inventoryList,
          PERMISSION_CODES.purchaseInboundList,
        ]),
      ).toBe(true)
    })
  })

  describe('hasAnyPermission', () => {
    it('should return true when user has at least one', () => {
      expect(
        hasAnyPermission(userPerms, [
          PERMISSION_CODES.inventoryList,
          PERMISSION_CODES.productionPickingList,
        ]),
      ).toBe(true)
    })

    it('should return false when user has none', () => {
      expect(
        hasAnyPermission(userPerms, [
          PERMISSION_CODES.productionPickingList,
          PERMISSION_CODES.salesOrderList,
        ]),
      ).toBe(false)
    })

    it('should return false for empty requirements', () => {
      expect(hasAnyPermission(userPerms, [])).toBe(false)
    })
  })

  describe('PERMISSION_CODES', () => {
    it('should have unique values', () => {
      const values = Object.values(PERMISSION_CODES)
      const unique = new Set(values)
      expect(unique.size).toBe(values.length)
    })

    it('should use colon-separated format', () => {
      Object.values(PERMISSION_CODES).forEach((code) => {
        expect(code).toMatch(/^[a-z]+(:[a-z-]+)+$/)
      })
    })
  })
})