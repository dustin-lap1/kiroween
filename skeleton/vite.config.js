import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// In dev, point /api at the deployed CloudFront URL:
//   $env:API_PROXY_TARGET = "https://dxxxxxxxx.cloudfront.net"; npm run dev
const apiTarget = process.env.API_PROXY_TARGET

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: apiTarget
    ? { proxy: { '/api': { target: apiTarget, changeOrigin: true, secure: true } } }
    : {},
})
