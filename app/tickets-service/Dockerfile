# HelpSphere tickets-service — Multi-stage Dockerfile (Story 06.5c.1, T8)
# Defesa Decisão #16: image runtime alpine ~80MB vs Debian ~200MB.
# Non-root user no runtime stage (security baseline).
# AC-6: image final < 250MB esperada (validar em CI Story 06.5c.5).

# ----- Stage 1: build -----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csprojs first for layer caching (npm-style)
# Story 06.5c.3 fix run #21: removido COPY de TicketsService.sln (real é .slnx
# XML format .NET 9+) e COPY de tests/csproj (excluido por .dockerignore + não
# necessário — `dotnet restore` da Api csproj resolve refs transitivas via
# ProjectReference para Domain + Infrastructure).
COPY ["Directory.Build.props", "./"]
COPY ["src/TicketsService.Api/TicketsService.Api.csproj", "src/TicketsService.Api/"]
COPY ["src/TicketsService.Domain/TicketsService.Domain.csproj", "src/TicketsService.Domain/"]
COPY ["src/TicketsService.Infrastructure/TicketsService.Infrastructure.csproj", "src/TicketsService.Infrastructure/"]
RUN dotnet restore "src/TicketsService.Api/TicketsService.Api.csproj"

# Copy source + publish
COPY src/ src/
RUN dotnet publish "src/TicketsService.Api/TicketsService.Api.csproj" \
    -c Release \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

# ----- Stage 2: runtime (alpine) -----
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS runtime
WORKDIR /app

# Microsoft.Data.SqlClient requer ICU (cultura completa) — Alpine .NET imagem
# vem com Globalization Invariant Mode por default. Sem icu-libs, qualquer
# tentativa de abrir SqlConnection lanca NotSupportedException.
RUN apk add --no-cache icu-libs icu-data-full

# Non-root user (security baseline)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build --chown=appuser:appgroup /app/publish .
USER appuser

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

ENTRYPOINT ["dotnet", "TicketsService.Api.dll"]
