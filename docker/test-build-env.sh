#!/bin/bash

# Simple test to verify Docker build infrastructure
# Creates a minimal test image to validate the build process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Testing Docker build infrastructure..."

# Create a minimal test Dockerfile
cat > "$PROJECT_ROOT/Dockerfile.test" << 'EOF'
FROM alpine:latest
RUN echo "Hello from BiliBiliToolPro build test!" > /test.txt
CMD cat /test.txt
EOF

echo "📦 Building test image..."
cd "$PROJECT_ROOT"

if docker build -f Dockerfile.test -t bilibili-tool-test:latest .; then
    echo "✅ Test image built successfully!"
    
    echo "🏃 Running test container..."
    if docker run --rm bilibili-tool-test:latest; then
        echo "✅ Test container ran successfully!"
        echo "🎉 Docker build infrastructure is working correctly!"
        
        # Clean up
        docker rmi bilibili-tool-test:latest
        rm -f Dockerfile.test
        
        echo ""
        echo "📋 Build readiness check:"
        echo "  ✅ Docker daemon accessible"
        echo "  ✅ Docker build functionality working"
        echo "  ✅ Container execution working"
        echo ""
        echo "🚀 Ready to build BiliBiliToolPro Docker image!"
        echo "    Run: ./docker/build.sh"
        
        exit 0
    else
        echo "❌ Test container failed to run"
        exit 1
    fi
else
    echo "❌ Test image build failed"
    echo "🔧 Please check Docker installation and daemon status"
    exit 1
fi