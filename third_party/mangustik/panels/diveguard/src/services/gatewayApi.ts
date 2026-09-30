/**
 * control-gateway client (CONTROL_INTERFACE_TZ.md Phase 6).
 *
 * Unlike services/api.ts (which talks to underwater-ai-platform directly on its own
 * port 8083, pre-dating this phase), everything here goes through the gateway on one
 * port - Phase 6's own readiness criterion. Status reads use the Phase 3 `/v2/status/...`
 * envelope; control commands use the Phase 1 raw proxy prefixes (`/dive-buddy/...`,
 * `/gaz2410/...`, `/video-streamer/...`) since Phase 3 only wraps GET status, not POST
 * commands, for any module - not just these new ones.
 */

import axios from 'axios'

const GATEWAY_BASE = import.meta.env.VITE_GATEWAY_URL || 'http://localhost:8080'
const GATEWAY_API_KEY = import.meta.env.VITE_GATEWAY_API_KEY || ''

export const gateway = axios.create({
  baseURL: GATEWAY_BASE,
  headers: GATEWAY_API_KEY ? { 'X-API-Key': GATEWAY_API_KEY } : {},
})

interface Envelope<T> {
  status: 'ok' | 'error'
  timestamp: string
  data: T | null
  error: string | null
}

async function fetchEnvelope<T>(path: string): Promise<T> {
  const response = await gateway.get<Envelope<T>>(path)
  if (response.data.status === 'error') {
    throw new Error(response.data.error ?? `gateway returned an error envelope for ${path}`)
  }
  return response.data.data as T
}

// --- dive-buddy (control-gateway/main.py STATUS_ENDPOINTS + dashboard_api.py) --------

export interface DiverFix {
  forward_m: number
  lateral_m: number
  depth_diff_m: number
}

export interface DiverVitals {
  heart_rate_bpm: number
  depth_m: number
  breathing_rate_bpm: number
  seconds_since_last_comms: number
}

export interface DiveBuddyStatus {
  state: string
  last_trigger_reason: string | null
  diver_fix: DiverFix | null
  obstacle_distance_m: number | null
  last_gesture: string | null
  vitals: DiverVitals | null
}

export type DiveBuddyGesture = 'EMERGENCY' | 'HOLD' | 'RESUME'

export function fetchDiveBuddyStatus(): Promise<DiveBuddyStatus> {
  return fetchEnvelope<DiveBuddyStatus>('/v2/status/dive-buddy')
}

export async function sendDiveBuddyGesture(gesture: DiveBuddyGesture): Promise<DiveBuddyStatus> {
  const response = await gateway.post<DiveBuddyStatus>('/dive-buddy/v1/mission/gesture', { gesture })
  return response.data
}

// --- companion-bridge (mavlink-router / video-streamer, Phase 4 status+control APIs) -

export interface MavlinkRouterStatus {
  connected: boolean
  messages_routed: number
  output_endpoints: string[]
}

export interface VideoStreamerStatus {
  is_running: boolean
  protocol: string
  output_host: string
  output_port: number
  bitrate_kbps: number
}

export function fetchMavlinkRouterStatus(): Promise<MavlinkRouterStatus> {
  return fetchEnvelope<MavlinkRouterStatus>('/v2/status/mavlink-router')
}

export function fetchVideoStreamerStatus(): Promise<VideoStreamerStatus> {
  return fetchEnvelope<VideoStreamerStatus>('/v2/status/video-streamer')
}

export async function startVideoStream(): Promise<VideoStreamerStatus> {
  const response = await gateway.post<VideoStreamerStatus>('/video-streamer/start')
  return response.data
}

export async function stopVideoStream(): Promise<VideoStreamerStatus> {
  const response = await gateway.post<VideoStreamerStatus>('/video-streamer/stop')
  return response.data
}

// --- gaz2410 (laser/bubbles/renderer status + control, existing endpoints) -----------

export interface Gaz2410Status {
  bubble_generator: Record<string, unknown>
  laser_controller: Record<string, unknown>
  renderer: Record<string, unknown>
  timestamp: number
}

export function fetchGaz2410Status(): Promise<Gaz2410Status> {
  return fetchEnvelope<Gaz2410Status>('/v2/status/gaz2410')
}

export async function setGaz2410LaserPower(powerW: number) {
  const response = await gateway.post('/gaz2410/api/v1/laser/power', null, {
    params: { power_w: powerW },
  })
  return response.data
}

export async function startGaz2410Bubbles(frequencyHz: number, dutyCycle: number) {
  const response = await gateway.post('/gaz2410/api/v1/bubble/start', null, {
    params: { frequency_hz: frequencyHz, duty_cycle: dutyCycle },
  })
  return response.data
}

export async function stopGaz2410Bubbles() {
  const response = await gateway.post('/gaz2410/api/v1/bubble/stop')
  return response.data
}
