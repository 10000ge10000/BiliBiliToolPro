# Docker Build Guide for BiliBiliToolPro

This guide provides comprehensive instructions for building Docker images for BiliBiliToolPro, including troubleshooting common issues and advanced build scenarios.

## 🚀 Quick Start

### Basic Build
```bash
# Navigate to project root
cd BiliBiliToolPro

# Basic build with default settings
./docker/build.sh

# Build with custom name and tag
./docker/build.sh -n my-bili-tool -t v1.0.0
```

### Run the Built Image
```bash
# Run the container
docker run -d -p 8080:8080 --name bili_tool bilibili_tool_pro:latest

# Access the web interface
open http://localhost:8080
```

## 🛠️ Build Options

### Standard Build Options
```bash
# Custom image name and tag
./docker/build.sh -n custom-name -t v2.0.0

# Build for ARM64 (Apple Silicon, ARM servers)
./docker/build.sh --platform linux/arm64

# Build with retry logic (useful for unstable networks)
./docker/build.sh --retry 5
```

### Multi-Architecture Builds
```bash
# Build for multiple architectures
./docker/build.sh --multi-arch

# Build for specific multiple platforms
./docker/build.sh --buildx --platform linux/amd64,linux/arm64
```

### Registry and Push Options
```bash
# Build and push to Docker Hub
./docker/build.sh -r docker.io/yourusername --push

# Build and push to GitHub Container Registry
./docker/build.sh -r ghcr.io/yourusername --push

# Build and push to Azure Container Registry
./docker/build.sh -r yourregistry.azurecr.io --push
```

### Advanced Build Features
```bash
# Use build cache (GitHub Actions)
./docker/build.sh --cache-from type=gha --cache-to type=gha

# Pass custom build arguments
./docker/build.sh --build-arg ENVIRONMENT=Production

# Combined advanced build
./docker/build.sh \
  --multi-arch \
  --registry ghcr.io/yourorg \
  --cache-from type=gha \
  --cache-to type=gha \
  --push
```

## 🏗️ Build Architecture

### Dockerfile Structure
```dockerfile
# Multi-stage build for optimal image size
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base      # Runtime base
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build       # Build environment
FROM build AS publish                                # Publish stage
FROM base AS final                                   # Final runtime image
```

### Build Process
1. **Base Stage**: Sets up ASP.NET Core runtime environment
2. **Build Stage**: Installs .NET SDK and restores NuGet packages
3. **Publish Stage**: Compiles and publishes the application
4. **Final Stage**: Creates minimal runtime image with published app

### Key Optimizations
- **Layer Caching**: Project files copied before source code for better cache utilization
- **Multi-stage Build**: Reduces final image size by excluding build tools
- **NuGet Optimization**: Retry logic and parallel disable for stability
- **Environment Variables**: Skip telemetry and first-time experience for faster builds

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. NuGet Connectivity Issues
**Error**: `Unable to load the service index for source https://api.nuget.org/v3/index.json`

**Solutions**:
```bash
# Increase retry count
./docker/build.sh --retry 5

# Check network connectivity
curl -I https://api.nuget.org/v3/index.json

# For corporate networks, configure proxy
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
```

#### 2. Docker Daemon Issues
**Error**: `Cannot connect to the Docker daemon`

**Solutions**:
```bash
# Start Docker daemon (Linux)
sudo systemctl start docker

# Start Docker Desktop (Windows/Mac)
# Ensure Docker Desktop is running

# Check Docker status
docker info
```

#### 3. Platform-Specific Issues
**Error**: `exec /app/entrypoint.sh: exec format error`

**Solutions**:
```bash
# Build for correct platform
./docker/build.sh --platform linux/amd64

# For ARM Mac building for x86
./docker/build.sh --platform linux/amd64 --buildx
```

#### 4. Memory Issues
**Error**: Build fails with out-of-memory errors

**Solutions**:
```bash
# Increase Docker memory limits
# Docker Desktop > Settings > Resources > Memory

# Use sequential restore (already configured in Dockerfile)
# Monitor system resources during build
docker stats
```

### Build Performance Tips

1. **Use Build Cache**:
   ```bash
   # Local cache
   ./docker/build.sh --cache-from type=local,src=/tmp/docker-cache

   # Registry cache
   ./docker/build.sh --cache-from type=registry,ref=myregistry/cache
   ```

2. **Parallel Builds**: Avoid when network is unstable
3. **Clean Environment**: Remove unused images to free space
   ```bash
   docker system prune -a
   ```

## 📁 Build Artifacts

### Image Layers
- **Base Layer**: ~150MB (ASP.NET Core runtime)
- **Application Layer**: ~50-100MB (compiled application)
- **Configuration Layer**: ~1MB (configs and scripts)

### Output Structure
```
/app/
├── Ray.BiliBiliTool.Web.dll    # Main application
├── appsettings.json            # Configuration
├── wwwroot/                    # Static files
├── config/                     # Runtime configuration
├── entrypoint.sh              # Startup script
└── ...                        # Dependencies
```

## 🌐 Registry Configuration

### Docker Hub
```bash
# Login
docker login

# Build and push
./docker/build.sh -r yourusername --push
```

### GitHub Container Registry
```bash
# Login with personal access token
echo $GITHUB_TOKEN | docker login ghcr.io -u yourusername --password-stdin

# Build and push
./docker/build.sh -r ghcr.io/yourusername --push
```

### Azure Container Registry
```bash
# Login
az acr login --name yourregistry

# Build and push
./docker/build.sh -r yourregistry.azurecr.io --push
```

## 🚀 CI/CD Integration

### GitHub Actions Example
```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build and push
      run: |
        ./docker/build.sh \
          --registry ghcr.io/${{ github.repository_owner }} \
          --tag ${{ github.ref_name }} \
          --multi-arch \
          --cache-from type=gha \
          --cache-to type=gha \
          --push
      env:
        DOCKER_BUILDKIT: 1
```

### Azure DevOps Example
```yaml
steps:
- task: Docker@2
  displayName: Build and push Docker image
  inputs:
    command: 'build'
    Dockerfile: 'Dockerfile'
    buildContext: '.'
    repository: '$(imageName)'
    tags: |
      $(Build.BuildId)
      latest
```

## 📋 Pre-build Checklist

Before building, ensure:
- [ ] Docker daemon is running
- [ ] Network connectivity to NuGet
- [ ] Sufficient disk space (>2GB recommended)
- [ ] Appropriate platform selected
- [ ] Registry credentials configured (if pushing)

## 🆘 Getting Help

If you encounter issues:
1. Check this troubleshooting guide
2. Review build logs for specific errors
3. Test network connectivity to required services
4. Consult the [project issues](https://github.com/RayWangQvQ/BiliBiliToolPro/issues)
5. Create a new issue with build logs and environment details

## 📖 Related Documentation

- [Docker Usage Guide](README.md)
- [Configuration Guide](../docs/configuration.md)
- [Deployment Guide](../docs/deployment.md)
- [Development Setup](../docs/development.md)

---

*Built with ❤️ by the BiliBiliToolPro community*