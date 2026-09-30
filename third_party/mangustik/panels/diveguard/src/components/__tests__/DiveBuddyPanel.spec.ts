import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import DiveBuddyPanel from '../DiveBuddyPanel.vue'
import * as gatewayApi from '../../services/gatewayApi'

vi.mock('../../services/gatewayApi', () => ({
  fetchDiveBuddyStatus: vi.fn(),
  sendDiveBuddyGesture: vi.fn(),
}))

const baseStatus = {
  state: 'FOLLOW',
  last_trigger_reason: null,
  diver_fix: null,
  obstacle_distance_m: null,
  last_gesture: null,
  vitals: null,
}

beforeEach(() => {
  vi.mocked(gatewayApi.fetchDiveBuddyStatus).mockReset()
  vi.mocked(gatewayApi.sendDiveBuddyGesture).mockReset()
})

describe('DiveBuddyPanel', () => {
  it('renders the mission state fetched on mount', async () => {
    vi.mocked(gatewayApi.fetchDiveBuddyStatus).mockResolvedValue({ ...baseStatus, state: 'FOLLOW' })

    const wrapper = mount(DiveBuddyPanel)
    await flushPromises()

    expect(wrapper.get('[data-testid=mission-state]').text()).toBe('FOLLOW')
    wrapper.unmount()
  })

  it('sends an EMERGENCY gesture through step() when the button is clicked', async () => {
    vi.mocked(gatewayApi.fetchDiveBuddyStatus).mockResolvedValue(baseStatus)
    vi.mocked(gatewayApi.sendDiveBuddyGesture).mockResolvedValue({
      ...baseStatus,
      state: 'EMERGENCY_ASCENT',
      last_trigger_reason: 'diver emergency gesture',
      last_gesture: 'EMERGENCY',
    })

    const wrapper = mount(DiveBuddyPanel)
    await flushPromises()

    await wrapper.get('[data-testid=gesture-EMERGENCY]').trigger('click')
    await flushPromises()

    expect(gatewayApi.sendDiveBuddyGesture).toHaveBeenCalledWith('EMERGENCY')
    expect(wrapper.get('[data-testid=mission-state]').text()).toBe('EMERGENCY_ASCENT')
    wrapper.unmount()
  })

  it('shows the gateway detail message when a gesture is rejected', async () => {
    vi.mocked(gatewayApi.fetchDiveBuddyStatus).mockResolvedValue(baseStatus)
    vi.mocked(gatewayApi.sendDiveBuddyGesture).mockRejectedValue({
      response: { data: { detail: 'no vitals available yet - mission telemetry has not started' } },
    })

    const wrapper = mount(DiveBuddyPanel)
    await flushPromises()

    await wrapper.get('[data-testid=gesture-HOLD]').trigger('click')
    await flushPromises()

    expect(wrapper.get('[data-testid=gesture-error]').text()).toBe(
      'no vitals available yet - mission telemetry has not started'
    )
    wrapper.unmount()
  })

  it('offers all three gesture buttons', async () => {
    vi.mocked(gatewayApi.fetchDiveBuddyStatus).mockResolvedValue(baseStatus)

    const wrapper = mount(DiveBuddyPanel)
    await flushPromises()

    expect(wrapper.find('[data-testid=gesture-EMERGENCY]').exists()).toBe(true)
    expect(wrapper.find('[data-testid=gesture-HOLD]').exists()).toBe(true)
    expect(wrapper.find('[data-testid=gesture-RESUME]').exists()).toBe(true)
    wrapper.unmount()
  })
})
