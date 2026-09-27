# Stage 1: Build the backend application
FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS build
WORKDIR /app

# Copy solution and project files for layer caching
COPY Messaging.slnx ./
COPY src/Messaging.Domain/Messaging.Domain.csproj src/Messaging.Domain/
COPY src/Messaging.Application/Messaging.Application.csproj src/Messaging.Application/
COPY src/Messaging.Infrastructure/Messaging.Infrastructure.csproj src/Messaging.Infrastructure/
COPY src/Messaging.Api/Messaging.Api.csproj src/Messaging.Api/

# Restore dependencies
RUN dotnet restore src/Messaging.Api/Messaging.Api.csproj

# Copy all source files and publish
COPY src/ ./src/
RUN dotnet publish src/Messaging.Api/Messaging.Api.csproj \
    -c Release \
    -o /app/publish \
    --no-restore

# Stage 2: Minimal 512MB-optimized runtime image (Alpine Linux)
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime
WORKDIR /app

# Memory & Performance optimization for Render Free Tier (512MB RAM cap):
# 1. Workstation GC (DOTNET_gcServer=0) drops base RAM usage from ~200MB to ~35MB.
# 2. Hard GC Heap limit 320MB (0x14000000) prevents GC from exceeding 512MB.
# 3. Disable diagnostics to save memory.
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_gcServer=0
ENV DOTNET_GCHeapHardLimit=0x14000000
ENV DOTNET_EnableDiagnostics=0
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Expose Render HTTP Port
EXPOSE 8080

COPY --from=build /app/publish .

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "Messaging.Api.dll"]
