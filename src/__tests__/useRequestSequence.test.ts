import { describe, it, expect } from 'vitest'
import { useRequestSequence } from '@/core/api/request-sequence'

describe('useRequestSequence', () => {
  it('should generate incrementing sequence IDs', () => {
    const seq = useRequestSequence()
    const id1 = seq.nextSequence()
    const id2 = seq.nextSequence()
    expect(id2).toBeGreaterThan(id1)
  })

  it('should recognize latest sequence', () => {
    const seq = useRequestSequence()
    const id = seq.nextSequence()
    expect(seq.isLatest(id)).toBe(true)
  })

  it('should reject old sequence after new one created', () => {
    const seq = useRequestSequence()
    const oldId = seq.nextSequence()
    seq.nextSequence()
    expect(seq.isLatest(oldId)).toBe(false)
  })

  it('should track completion', () => {
    const seq = useRequestSequence()
    const id = seq.nextSequence()
    seq.markComplete(id)
    expect(seq.isLatest(id)).toBe(true)
  })

  it('should cancel all pending on new sequence', () => {
    const seq = useRequestSequence()
    const id1 = seq.nextSequence()
    const { controller, check } = seq.createAbortController(id1)

    seq.nextSequence()
    check()

    expect(controller.signal.aborted).toBe(true)
  })

  it('should allow latest sequence through', () => {
    const seq = useRequestSequence()
    const id = seq.nextSequence()

    const { controller } = seq.createAbortController(id)

    expect(controller.signal.aborted).toBe(false)
  })
})