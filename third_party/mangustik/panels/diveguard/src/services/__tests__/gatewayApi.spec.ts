import { describe, it, expect, vi, beforeEach } from 'vitest'

const { mockGet, mockPost } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPost: vi.fn(),
}))

vi.mock('axios', () => ({
  default: {
    create: () => ({ get: mockGet, post: mockPost }),
  },
}))

import {
  fetchDiveBuddyStatus,
  sendDiveBuddyGesture,
  fetchMavlinkRouterStatus,
  fetchVideoStreamerStatus,
  startVideoStream,
  stopVideoStream,
  fetchGaz2410Status,
  setGaz2410LaserPower,
  startGaz2410Bubbles,
  stopGaz2410Bubbles,
} from '../gatewayApi'

beforeEach(() => {
  mockGet.mockReset()
  mockPost.mockReset()
})

describe('fetchDiveBuddyStatus', () => {
  it('unwraps the envelope data on success', async () => {
    mockGet.mockResolvedValue({
      data: { status: 'ok', timestamp: 't', data: { state: 'FOLLOW' }, error: null },
    })

    const result = await fetchDiveBuddyStatus()

    expect(mockGet).toHaveBeenCalledWith('/v2/status/dive-buddy')
    expect(result).toEqual({ state: 'FOLLOW' })
  })

  it('throws when the gateway returns an error envelope', async () => {
    mockGet.mockResolvedValue({
      data: { status: 'error', timestamp: 't', data: null, error: 'upstream unavailable' },
    })

    await expect(fetchDiveBuddyStatus()).rejects.toThrow('upstream unavailable')
  })
})

describe('sendDiveBuddyGesture', () => {
  it('posts the gesture through the raw proxy prefix and returns the response body', async () => {
    mockPost.mockResolvedValue({ data: { state: 'EMERGENCY_ASCENT' } })

    const result = await sendDiveBuddyGesture('EMERGENCY')

    expect(mockPost).toHaveBeenCalledWith('/dive-buddy/v1/mission/gesture', { gesture: 'EMERGENCY' })
    expect(result).toEqual({ state: 'EMERGENCY_ASCENT' })
  })
})

describe('companion-bridge status/control', () => {
  it('fetches mavlink-router status via the v2 envelope', async () => {
    mockGet.mockResolvedValue({
      data: { status: 'ok', timestamp: 't', data: { connected: true, messages_routed: 5 }, error: null },
    })

    const result = await fetchMavlinkRouterStatus()

    expect(mockGet).toHaveBeenCalledWith('/v2/status/mavlink-router')
    expect(result).toEqual({ connected: true, messages_routed: 5 })
  })

  it('fetches video-streamer status via the v2 envelope', async () => {
    mockGet.mockResolvedValue({
      data: { status: 'ok', timestamp: 't', data: { is_running: false }, error: null },
    })

    const result = await fetchVideoStreamerStatus()

    expect(mockGet).toHaveBeenCalledWith('/v2/status/video-streamer')
    expect(result).toEqual({ is_running: false })
  })

  it('starts the video stream through the raw proxy prefix', async () => {
    mockPost.mockResolvedValue({ data: { is_running: true } })

    const result = await startVideoStream()

    expect(mockPost).toHaveBeenCalledWith('/video-streamer/start')
    expect(result).toEqual({ is_running: true })
  })

  it('stops the video stream through the raw proxy prefix', async () => {
    mockPost.mockResolvedValue({ data: { is_running: false } })

    const result = await stopVideoStream()

    expect(mockPost).toHaveBeenCalledWith('/video-streamer/stop')
    expect(result).toEqual({ is_running: false })
  })
})

describe('gaz2410 status/control', () => {
  it('fetches gaz2410 status via the v2 envelope', async () => {
    mockGet.mockResolvedValue({
      data: { status: 'ok', timestamp: 't', data: { timestamp: 1 }, error: null },
    })

    const result = await fetchGaz2410Status()

    expect(mockGet).toHaveBeenCalledWith('/v2/status/gaz2410')
    expect(result).toEqual({ timestamp: 1 })
  })

  it('sets laser power as a power_w query param, matching the backend signature', async () => {
    mockPost.mockResolvedValue({ data: { status: 'laser_power_set' } })

    await setGaz2410LaserPower(2.5)

    expect(mockPost).toHaveBeenCalledWith('/gaz2410/api/v1/laser/power', null, { params: { power_w: 2.5 } })
  })

  it('starts bubbles with frequency_hz/duty_cycle query params', async () => {
    mockPost.mockResolvedValue({ data: { status: 'bubbles_started' } })

    await startGaz2410Bubbles(40000, 0.5)

    expect(mockPost).toHaveBeenCalledWith('/gaz2410/api/v1/bubble/start', null, {
      params: { frequency_hz: 40000, duty_cycle: 0.5 },
    })
  })

  it('stops bubbles with no params', async () => {
    mockPost.mockResolvedValue({ data: { status: 'bubbles_stopped' } })

    await stopGaz2410Bubbles()

    expect(mockPost).toHaveBeenCalledWith('/gaz2410/api/v1/bubble/stop')
  })
})
