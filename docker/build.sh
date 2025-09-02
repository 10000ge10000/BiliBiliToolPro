#!/bin/bash

# Docker Image Build Script for BiliBiliToolPro
# This script provides multiple build options with retry logic and error handling
# 
# Author: BiliBiliToolPro Team
# Version: 1.0
# 
# This script supports:
# - Standard Docker build
# - Multi-architecture builds using buildx
# - Retry logic for network issues
# - Comprehensive logging and error handling
# - Multiple registry support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
IMAGE_NAME="bilibili_tool_pro"
TAG="latest"
PLATFORM="linux/amd64"
PUSH=false
RETRY_COUNT=3
BUILD_ARG_EXTRA=""
REGISTRY=""
CACHE_FROM=""
CACHE_TO=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build BiliBiliToolPro Docker image with retry logic and error handling.

This script provides multiple build strategies to handle various network and
platform requirements commonly encountered when building .NET applications
in containerized environments.

OPTIONS:
    -h, --help              Show this help message
    -n, --name NAME         Image name (default: bilibili_tool_pro)
    -t, --tag TAG           Image tag (default: latest)
    -p, --platform PLATFORM Platform (default: linux/amd64)
    -r, --registry REGISTRY Registry URL (e.g., docker.io, ghcr.io)
    --multi-arch            Build for multiple architectures (linux/amd64,linux/arm64)
    --push                  Push image to registry after build
    --retry COUNT           Number of retry attempts (default: 3)
    --buildx                Use buildx for build (enables multi-platform)
    --cache-from SOURCE     Import build cache from external source
    --cache-to DEST         Export build cache to external destination
    --build-arg ARG=VALUE   Pass build arguments to Docker

EXAMPLES:
    $0                                          # Basic build
    $0 -n myimage -t v1.0.0                     # Custom name and tag
    $0 --multi-arch --push                     # Multi-arch build with push
    $0 --buildx --platform linux/arm64         # ARM64 build with buildx
    $0 -r ghcr.io/user --push                  # Push to GitHub Container Registry
    $0 --cache-from type=gha --cache-to type=gha # Use GitHub Actions cache

NETWORK ISSUES:
    If you encounter NuGet connectivity issues, try:
    - Ensure your network allows access to api.nuget.org
    - Check DNS settings (some environments require specific DNS servers)
    - Consider using --retry with higher count
    - For corporate networks, you may need to configure proxy settings

REGISTRY EXAMPLES:
    Docker Hub:      docker.io/username
    GitHub:          ghcr.io/username
    Azure:          yourregistry.azurecr.io
    AWS ECR:        123456789012.dkr.ecr.region.amazonaws.com

EOF
}

check_dependencies() {
    log_step "Checking build dependencies..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        log_info "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        log_info "Please start Docker daemon"
        exit 1
    fi
    
    # Check Docker version
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    log_debug "Docker version: $docker_version"
    
    # Check buildx availability if needed
    if [[ "$USE_BUILDX" == "true" ]]; then
        if ! docker buildx version &> /dev/null; then
            log_error "Docker buildx is not available"
            log_info "Please ensure Docker buildx is installed"
            exit 1
        fi
        log_debug "buildx available"
    fi
    
    log_success "Dependencies check passed"
}

check_network_connectivity() {
    log_step "Checking network connectivity for NuGet..."
    
    # Test NuGet API connectivity
    if timeout 10 curl -s https://api.nuget.org/v3/index.json > /dev/null 2>&1; then
        log_success "NuGet API is accessible"
        return 0
    else
        log_warning "NuGet API connectivity test failed"
        log_warning "This may cause build failures. Consider:"
        log_warning "  - Checking your network connection"
        log_warning "  - Configuring proxy settings if behind corporate firewall"
        log_warning "  - Using --retry with higher count"
        return 1
    fi
}

prepare_build_environment() {
    log_step "Preparing build environment..."
    
    cd "$PROJECT_ROOT"
    
    # Verify Dockerfile exists
    if [[ ! -f "Dockerfile" ]]; then
        log_error "Dockerfile not found in project root"
        exit 1
    fi
    
    # Verify required source files exist
    if [[ ! -d "src" ]]; then
        log_error "Source directory 'src' not found"
        exit 1
    fi
    
    log_debug "Build environment ready"
}

build_image() {
    local attempt=1
    local build_cmd=""
    local full_image_name=""
    
    # Construct full image name with registry if provided
    if [[ -n "$REGISTRY" ]]; then
        full_image_name="${REGISTRY}/${IMAGE_NAME}:${TAG}"
    else
        full_image_name="${IMAGE_NAME}:${TAG}"
    fi
    
    log_step "Building Docker image: $full_image_name"
    
    # Construct build command
    if [[ "$USE_BUILDX" == "true" ]]; then
        log_info "Using Docker buildx for build"
        build_cmd="docker buildx build --platform $PLATFORM"
        
        # Add cache options if specified
        if [[ -n "$CACHE_FROM" ]]; then
            build_cmd="$build_cmd --cache-from $CACHE_FROM"
        fi
        if [[ -n "$CACHE_TO" ]]; then
            build_cmd="$build_cmd --cache-to $CACHE_TO"
        fi
        
        if [[ "$PUSH" == "true" ]]; then
            build_cmd="$build_cmd --push"
        else
            build_cmd="$build_cmd --load"
        fi
    else
        log_info "Using standard Docker build"
        build_cmd="docker build"
    fi
    
    build_cmd="$build_cmd -t $full_image_name $BUILD_ARG_EXTRA ."
    
    log_debug "Build command: $build_cmd"
    
    while [[ $attempt -le $RETRY_COUNT ]]; do
        log_info "Build attempt $attempt of $RETRY_COUNT..."
        
        # Start timer
        local start_time
        start_time=$(date +%s)
        
        if eval "$build_cmd"; then
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            log_success "Docker image built successfully in ${duration}s: $full_image_name"
            
            # Show image info
            if [[ "$USE_BUILDX" != "true" || "$PUSH" != "true" ]]; then
                log_info "Image details:"
                docker images "$IMAGE_NAME:$TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"
            fi
            
            return 0
        else
            log_warning "Build attempt $attempt failed"
            if [[ $attempt -lt $RETRY_COUNT ]]; then
                local wait_time=$((attempt * 10))
                log_info "Retrying in ${wait_time} seconds..."
                sleep $wait_time
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Failed to build Docker image after $RETRY_COUNT attempts"
    return 1
}

test_image() {
    if [[ "$PUSH" == "true" || "$USE_BUILDX" == "true" ]]; then
        log_info "Skipping image test (buildx or push mode)"
        return 0
    fi
    
    local full_image_name="${IMAGE_NAME}:${TAG}"
    log_step "Testing built image: $full_image_name"
    
    # Test if image can start and shows help or version info
    log_debug "Testing image startup..."
    if timeout 30 docker run --rm "$full_image_name" --help &> /dev/null; then
        log_success "Image test passed - help command works"
    elif timeout 30 docker run --rm "$full_image_name" --version &> /dev/null; then
        log_success "Image test passed - version command works"
    else
        log_warning "Image test: help/version commands failed, but image is available"
        log_debug "This is normal for web applications that don't support CLI flags"
    fi
}

cleanup_temp_files() {
    # Clean up any temporary files if they exist
    if [[ -f "$PROJECT_ROOT/Dockerfile.build" ]]; then
        rm -f "$PROJECT_ROOT/Dockerfile.build"
        log_debug "Cleaned up temporary build files"
    fi
}

main() {
    local USE_BUILDX=false
    local MULTI_ARCH=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            -t|--tag)
                TAG="$2"
                shift 2
                ;;
            -p|--platform)
                PLATFORM="$2"
                shift 2
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            --multi-arch)
                MULTI_ARCH=true
                PLATFORM="linux/amd64,linux/arm64"
                USE_BUILDX=true
                shift
                ;;
            --push)
                PUSH=true
                shift
                ;;
            --retry)
                RETRY_COUNT="$2"
                shift 2
                ;;
            --buildx)
                USE_BUILDX=true
                shift
                ;;
            --cache-from)
                CACHE_FROM="$2"
                USE_BUILDX=true
                shift 2
                ;;
            --cache-to)
                CACHE_TO="$2"
                USE_BUILDX=true
                shift 2
                ;;
            --build-arg)
                BUILD_ARG_EXTRA="$BUILD_ARG_EXTRA --build-arg $2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Banner
    echo -e "${CYAN}"
    echo "================================================="
    echo "    BiliBiliToolPro Docker Build Script"
    echo "================================================="
    echo -e "${NC}"
    
    log_info "Starting Docker image build process..."
    log_info "Image: ${IMAGE_NAME}:${TAG}"
    if [[ -n "$REGISTRY" ]]; then
        log_info "Registry: $REGISTRY"
    fi
    log_info "Platform: $PLATFORM"
    log_info "Push: $PUSH"
    log_info "Retry count: $RETRY_COUNT"
    log_info "Use buildx: $USE_BUILDX"
    
    # Set up buildx if needed
    if [[ "$USE_BUILDX" == "true" ]]; then
        log_step "Setting up buildx..."
        docker buildx create --use --name bili-builder 2>/dev/null || true
        docker buildx inspect --bootstrap
    fi
    
    check_dependencies
    check_network_connectivity
    prepare_build_environment
    
    # Trap to ensure cleanup
    trap cleanup_temp_files EXIT
    
    if build_image; then
        test_image
        log_success "Build process completed successfully! 🎉"
        
        echo
        log_info "Next steps:"
        if [[ "$PUSH" != "true" ]]; then
            log_info "  📦 To run the container:"
            log_info "     docker run -d -p 8080:8080 --name bili_tool ${IMAGE_NAME}:${TAG}"
            log_info "  🌐 Access the web interface at: http://localhost:8080"
        else
            log_info "  ✅ Image has been pushed to registry"
        fi
        log_info "  📝 Check docker/README.md for more usage examples"
        
    else
        log_error "Build process failed! ❌"
        echo
        log_info "Troubleshooting tips:"
        log_info "  🔧 Check network connectivity to NuGet"
        log_info "  🔄 Try increasing retry count with --retry"
        log_info "  📋 Review the build logs above for specific errors"
        log_info "  🐛 Report issues at: https://github.com/RayWangQvQ/BiliBiliToolPro/issues"
        exit 1
    fi
}

main "$@"