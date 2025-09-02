#See https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/docker/building-net-docker-images
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /code

# Set environment variables for better build experience
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
ENV DOTNET_CLI_TELEMETRY_OPTOUT=true
ENV NUGET_XMLDOC_MODE=skip

# Copy package management files first for better caching
COPY ["Directory.Packages.props", "./"]
COPY ["src/Ray.BiliBiliTool.Web/Ray.BiliBiliTool.Web.csproj", "src/Ray.BiliBiliTool.Web/"]
COPY ["src/Ray.BiliBiliTool.Web.Client/Ray.BiliBiliTool.Web.Client.csproj", "src/Ray.BiliBiliTool.Web.Client/"]
COPY ["src/Ray.BiliBiliTool.Application/Ray.BiliBiliTool.Application.csproj", "src/Ray.BiliBiliTool.Application/"]
COPY ["src/Ray.BiliBiliTool.Application.Contracts/Ray.BiliBiliTool.Application.Contracts.csproj", "src/Ray.BiliBiliTool.Application.Contracts/"]
COPY ["src/Ray.BiliBiliTool.Domain/Ray.BiliBiliTool.Domain.csproj", "src/Ray.BiliBiliTool.Domain/"]
COPY ["src/Ray.BiliBiliTool.DomainService/Ray.BiliBiliTool.DomainService.csproj", "src/Ray.BiliBiliTool.DomainService/"]
COPY ["src/Ray.BiliBiliTool.Config/Ray.BiliBiliTool.Config.csproj", "src/Ray.BiliBiliTool.Config/"]
COPY ["src/Ray.BiliBiliTool.Agent/Ray.BiliBiliTool.Agent.csproj", "src/Ray.BiliBiliTool.Agent/"]
COPY ["src/Ray.BiliBiliTool.Infrastructure/Ray.BiliBiliTool.Infrastructure.csproj", "src/Ray.BiliBiliTool.Infrastructure/"]
COPY ["src/Ray.BiliBiliTool.Infrastructure.EF/Ray.BiliBiliTool.Infrastructure.EF.csproj", "src/Ray.BiliBiliTool.Infrastructure.EF/"]
COPY ["src/BlazingQuartz.Core/BlazingQuartz.Core.csproj", "src/BlazingQuartz.Core/"]
COPY ["src/BlazingQuartz.Jobs/BlazingQuartz.Jobs.csproj", "src/BlazingQuartz.Jobs/"]
COPY ["src/BlazingQuartz.Jobs.Abstractions/BlazingQuartz.Jobs.Abstractions.csproj", "src/BlazingQuartz.Jobs.Abstractions/"]

# Restore packages with retry logic using shell script
RUN i=1; while [ $i -le 5 ]; do \
    echo "Restore attempt $i..."; \
    dotnet restore "src/Ray.BiliBiliTool.Web/Ray.BiliBiliTool.Web.csproj" \
        --disable-parallel \
        --verbosity minimal \
        --force \
        --no-cache && break || \
    (echo "Restore attempt $i failed, waiting..." && sleep $((i * 5))); \
    i=$((i + 1)); \
    done && \
    echo "Package restore completed"

COPY . .
WORKDIR "/code/src/Ray.BiliBiliTool.Web"
RUN dotnet build "Ray.BiliBiliTool.Web.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Ray.BiliBiliTool.Web.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN rm -rf /var/lib/apt/lists/* \
    && chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
