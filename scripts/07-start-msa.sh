#!/bin/bash
echo ""
echo "========================================="
echo "  🔀 MSA 모드로 시작합니다"
echo ""
echo "  ☕ Catalog Service  → localhost:3001"
echo "  📦 Order Service    → localhost:3002"
echo "  🌐 API Gateway      → localhost:4000"
echo "  💻 Frontend         → localhost:5173"
echo "========================================="
echo ""
yarn msa
