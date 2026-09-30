import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import Gaz2410Panel from '../Gaz2410Panel.vue'
import * as gatewayApi from '../../services/gatewayApi'

vi.mock('../../services/gatewayApi', () => ({
  fetchGaz2410Status: vi.fn(),
  setGaz2410LaserPower: vi.fn(),
  startGaz2410Bubbles: vi.fn(),
  stopGaz2410Bubbles: vi.fn(),
}))

const status = {
  bubble_generator: {},
  laser_controller: {},
  renderer: {},
  timestamp: 123,
}

beforeEach(() => {
  vi.mocked(gatewayApi.fetchGaz2410Status).mockReset().mockResolvedValue(status)
  vi.mocked(gatewayApi.setGaz2410LaserPower).mockReset()
  vi.mocked(gatewayApi.startGaz2410Bubbles).mockReset()
  vi.mocked(gatewayApi.stopGaz2410Bubbles).mockReset()
})

describe('Gaz2410Panel', () => {
  it('shows online once status is fetched on mount', async () => {
    const wrapper = mount(Gaz2410Panel)
    await flushPromises()

    expect(wrapper.get('[data-testid=gaz2410-status]').text()).toBe('online')
    wrapper.unmount()
  })

  it('sets laser power using the input value', async () => {
    vi.mocked(gatewayApi.setGaz2410LaserPower).mockResolvedValue({ status: 'laser_power_set' })

    const wrapper = mount(Gaz2410Panel)
    await flushPromises()

    await wrapper.get('[data-testid=laser-power-input]').setValue(3.5)
    await wrapper.get('[data-testid=laser-power-set]').trigger('click')
    await flushPromises()

    expect(gatewayApi.setGaz2410LaserPower).toHaveBeenCalledWith(3.5)
    wrapper.unmount()
  })

  it('starts bubbles when Start is clicked', async () => {
    vi.mocked(gatewayApi.startGaz2410Bubbles).mockResolvedValue({ status: 'bubbles_started' })

    const wrapper = mount(Gaz2410Panel)
    await flushPromises()

    await wrapper.get('[data-testid=bubbles-start]').trigger('click')
    await flushPromises()

    expect(gatewayApi.startGaz2410Bubbles).toHaveBeenCalled()
    wrapper.unmount()
  })

  it('stops bubbles when Stop is clicked', async () => {
    vi.mocked(gatewayApi.stopGaz2410Bubbles).mockResolvedValue({ status: 'bubbles_stopped' })

    const wrapper = mount(Gaz2410Panel)
    await flushPromises()

    await wrapper.get('[data-testid=bubbles-stop]').trigger('click')
    await flushPromises()

    expect(gatewayApi.stopGaz2410Bubbles).toHaveBeenCalled()
    wrapper.unmount()
  })

  it('shows an error message when a bubble command fails', async () => {
    vi.mocked(gatewayApi.startGaz2410Bubbles).mockRejectedValue(new Error('boom'))

    const wrapper = mount(Gaz2410Panel)
    await flushPromises()

    await wrapper.get('[data-testid=bubbles-start]').trigger('click')
    await flushPromises()

    expect(wrapper.get('[data-testid=gaz2410-error]').text()).toBe('Failed to start bubbles')
    wrapper.unmount()
  })
})
