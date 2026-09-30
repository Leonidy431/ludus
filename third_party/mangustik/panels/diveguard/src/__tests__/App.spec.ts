import { describe, it, expect, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import App from '../App.vue'
import DiveBuddyPanel from '../components/DiveBuddyPanel.vue'
import CompanionBridgePanel from '../components/CompanionBridgePanel.vue'
import Gaz2410Panel from '../components/Gaz2410Panel.vue'

// App.vue's onMounted() opens a real WebSocket and polls services/api.ts over HTTP -
// both fail gracefully in jsdom (no server, no native WebSocket) and are already
// wrapped in try/catch there, so no extra mocking is needed for this test to be
// meaningful: it's exercising Phase 6's new tab navigation, not the pre-existing
// DiveGuard live-data wiring.
describe('App tab navigation (CONTROL_INTERFACE_TZ.md Phase 6)', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('defaults to the diveguard tab with the new module panels hidden', async () => {
    const wrapper = mount(App, { shallow: true })
    await flushPromises()

    expect(wrapper.findComponent(DiveBuddyPanel).exists()).toBe(false)
    expect(wrapper.findComponent(CompanionBridgePanel).exists()).toBe(false)
    expect(wrapper.findComponent(Gaz2410Panel).exists()).toBe(false)
    wrapper.unmount()
  })

  it('switching to the dive-buddy tab shows the dive-buddy panel only', async () => {
    const wrapper = mount(App, { shallow: true })
    await flushPromises()

    await wrapper.get('[data-testid=tab-dive-buddy]').trigger('click')

    expect(wrapper.findComponent(DiveBuddyPanel).exists()).toBe(true)
    expect(wrapper.findComponent(CompanionBridgePanel).exists()).toBe(false)
    wrapper.unmount()
  })

  it('switching to the companion-bridge tab shows the companion-bridge panel only', async () => {
    const wrapper = mount(App, { shallow: true })
    await flushPromises()

    await wrapper.get('[data-testid=tab-companion-bridge]').trigger('click')

    expect(wrapper.findComponent(CompanionBridgePanel).exists()).toBe(true)
    expect(wrapper.findComponent(DiveBuddyPanel).exists()).toBe(false)
    wrapper.unmount()
  })

  it('switching to the gaz2410 tab shows the gaz2410 panel only', async () => {
    const wrapper = mount(App, { shallow: true })
    await flushPromises()

    await wrapper.get('[data-testid=tab-gaz2410]').trigger('click')

    expect(wrapper.findComponent(Gaz2410Panel).exists()).toBe(true)
    expect(wrapper.findComponent(CompanionBridgePanel).exists()).toBe(false)
    wrapper.unmount()
  })

  it('switching back to diveguard hides every module panel again', async () => {
    const wrapper = mount(App, { shallow: true })
    await flushPromises()

    await wrapper.get('[data-testid=tab-gaz2410]').trigger('click')
    await wrapper.get('[data-testid=tab-diveguard]').trigger('click')

    expect(wrapper.findComponent(Gaz2410Panel).exists()).toBe(false)
    expect(wrapper.findComponent(DiveBuddyPanel).exists()).toBe(false)
    expect(wrapper.findComponent(CompanionBridgePanel).exists()).toBe(false)
    wrapper.unmount()
  })
})
