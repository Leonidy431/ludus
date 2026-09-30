let ws: WebSocket | null = null

export async function initWebSocket(onMessage: (event: any) => void): Promise<void> {
  return new Promise((resolve, reject) => {
    try {
      ws = new WebSocket('ws://localhost:8083/v1/detection/stream')

      ws.onopen = () => {
        console.log('WebSocket connected')
        resolve()
      }

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          onMessage(data)
        } catch (err) {
          console.error('Failed to parse WebSocket message:', err)
        }
      }

      ws.onerror = (error) => {
        console.error('WebSocket error:', error)
        reject(error)
      }

      ws.onclose = () => {
        console.log('WebSocket disconnected')
      }

      // Timeout if not connected within 5s
      setTimeout(() => {
        if (ws?.readyState !== WebSocket.OPEN) {
          reject(new Error('WebSocket connection timeout'))
        }
      }, 5000)
    } catch (err) {
      reject(err)
    }
  })
}

export function closeWebSocket() {
  if (ws) {
    ws.close()
    ws = null
  }
}

export function isConnected(): boolean {
  return ws?.readyState === WebSocket.OPEN
}
