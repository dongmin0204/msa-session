import react from '@vitejs/plugin-react-swc';
import { defineConfig } from 'vite';

// MSA 모드: API 요청을 Gateway(port 4000)로 프록시
// Gateway가 Catalog Service / Order Service로 라우팅
export default defineConfig({
  plugins: [
    react({ jsxImportSource: '@emotion/react' }),
  ],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true,
      },
    },
  },
});
