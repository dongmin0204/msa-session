import react from '@vitejs/plugin-react-swc';
import { defineConfig } from 'vite';

// 프론트엔드 빌드 전용 (S3 업로드용)
// API는 CloudFront가 /api/* → API Gateway로 프록시하므로 상대 경로 그대로 사용
export default defineConfig({
  plugins: [
    react({ jsxImportSource: '@emotion/react' }),
  ],
  build: {
    outDir: 'dist',
  },
});
