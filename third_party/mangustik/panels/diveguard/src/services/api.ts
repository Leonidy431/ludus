import axios from 'axios'

const API_BASE = 'http://localhost:8083/v1'

export async function fetchSystemHealth() {
  const response = await axios.get(`${API_BASE}/health`)
  return response.data
}

export async function fetchDetectionStatus() {
  const response = await axios.get(`${API_BASE}/detection/status`)
  return response.data
}

export async function fetchMetricsLatency() {
  const response = await axios.get(`${API_BASE}/metrics/latency`)
  return response.data
}

export async function fetchDetectionHistory(limit: number = 50, offset: number = 0) {
  const response = await axios.get(`${API_BASE}/metrics/history`, {
    params: { limit, offset }
  })
  return response.data
}

export async function getConfigThreshold() {
  const response = await axios.get(`${API_BASE}/config/threshold`)
  return response.data
}

export async function setConfigThreshold(config: any) {
  const response = await axios.post(`${API_BASE}/config/threshold`, config)
  return response.data
}

export async function calibrateEnvironment(params: {
  temperature_c: number
  salinity_psu: number
  depth_m: number
}) {
  const response = await axios.post(`${API_BASE}/calibration/environment`, params)
  return response.data
}
