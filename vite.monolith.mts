import devServer from '@hono/vite-dev-server';
import react from '@vitejs/plugin-react-swc';
import { defineConfig } from 'vite';

// 모놀리식 모드: 하나의 서버가 모든 API를 처리
export default defineConfig({
  plugins: [
    react({ jsxImportSource: '@emotion/react' }),
    devServer({
      entry: './monolith/server.mjs',
      exclude: [/^(?!\/api).*/],
    }),
  ],
});
