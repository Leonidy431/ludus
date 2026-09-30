import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import CompanionBridgePanel from '../CompanionBridgePanel.vue'
import * as gatewayApi from '../../services/gatewayApi'

vi.mock('../../services/gatewayApi', () => ({
  fetchMavlinkRouterStatus: vi.fn(),
  fetchVideoStreamerStatus: vi.fn(),
  startVideoStream: vi.fn(),
  stopVideoStream: vi.fn(),
}))

const mavlinkStatus = { connected: true, messages_routed: 12, output_endpoints: ['udp:0.0.0.0:14550'] }
const videoStatusStopped = {
  is_running: false,
  protocol: 'udp',
  output_host: '0.0.0.0',
  output_port: 5600,
  bitrate_kbps: 2000,
}

beforeEach(() => {
  vi.mocked(gatewayApi.fetchMavlinkRouterStatus).mockReset().mockResolvedValue(mavlinkStatus)
  vi.mocked(gatewayApi.fetchVideoStreamerStatus).mockReset().mockResolvedValue(videoStatusStopped)
  vi.mocked(gatewayApi.startVideoStream).mockReset()
  vi.mocked(gatewayApi.stopVideoStream).mockReset()
})

describe('CompanionBridgePanel', () => {
  it('renders mavlink-router and video-streamer status fetched on mount', async () => {
    const wrapper = mount(CompanionBridgePanel)
    await flushPromises()

    expect(wrapper.get('[data-testid=mavlink-connected]').text()).toBe('yes')
    expect(wrapper.get('[data-testid=stream-running]').text()).toBe('no')
    wrapper.unmount()
  })

  it('starts the video stream when Start is clicked', async () => {
    vi.mocked(gatewayApi.startVideoStream).mockResolvedValue({ ...videoStatusStopped, is_running: true })

    const wrapper = mount(CompanionBridgePanel)
    await flushPromises()

    await wrapper.get('[data-testid=stream-start]').trigger('click')
    await flushPromises()

    expect(gatewayApi.startVideoStream).toHaveBeenCalled()
    expect(wrapper.get('[data-testid=stream-running]').text()).toBe('yes')
    wrapper.unmount()
  })

  it('stops the video stream when Stop is clicked', async () => {
    vi.mocked(gatewayApi.fetchVideoStreamerStatus).mockResolvedValue({ ...videoStatusStopped, is_running: true })
    vi.mocked(gatewayApi.stopVideoStream).mockResolvedValue({ ...videoStatusStopped, is_running: false })

    const wrapper = mount(CompanionBridgePanel)
    await flushPromises()

    await wrapper.get('[data-testid=stream-stop]').trigger('click')
    await flushPromises()

    expect(gatewayApi.stopVideoStream).toHaveBeenCalled()
    expect(wrapper.get('[data-testid=stream-running]').text()).toBe('no')
    wrapper.unmount()
  })

  it('shows an error message when start fails', async () => {
    vi.mocked(gatewayApi.startVideoStream).mockRejectedValue(new Error('boom'))

    const wrapper = mount(CompanionBridgePanel)
    await flushPromises()

    await wrapper.get('[data-testid=stream-start]').trigger('click')
    await flushPromises()

    expect(wrapper.get('[data-testid=stream-error]').text()).toBe('Failed to start video stream')
    wrapper.unmount()
  })
})
