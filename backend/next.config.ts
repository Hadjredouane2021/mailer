import type { NextConfig } from 'next';

// L'app Flutter (web) peut tourner sur une autre origine en développement : CORS
// ouvert, l'accès est protégé par le jeton API_TOKEN (en-tête Authorization).
const corsHeaders = [
  { key: 'Access-Control-Allow-Origin', value: '*' },
  { key: 'Access-Control-Allow-Methods', value: 'GET,POST,PUT,PATCH,DELETE,OPTIONS' },
  { key: 'Access-Control-Allow-Headers', value: 'Authorization, Content-Type' },
  { key: 'Access-Control-Max-Age', value: '86400' },
];

const nextConfig: NextConfig = {
  serverExternalPackages: ['mysql2', 'nodemailer'],
  async headers() {
    return [{ source: '/api/:path*', headers: corsHeaders }];
  },
  // Build web de l'app Flutter copié dans public/app (npm run build:app).
  async rewrites() {
    return [
      { source: '/app', destination: '/app/index.html' },
      { source: '/app/', destination: '/app/index.html' },
    ];
  },
};

export default nextConfig;
