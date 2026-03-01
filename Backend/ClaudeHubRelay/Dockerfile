# ================================
# Build stage
# ================================
FROM swift:6.0-noble AS build

WORKDIR /workspace

COPY Packages/ClaudeHubRemote Packages/ClaudeHubRemote
COPY Backend/ClaudeHubRelay Backend/ClaudeHubRelay

WORKDIR /workspace/Backend/ClaudeHubRelay

RUN swift build -c release

# ================================
# Run stage
# ================================
FROM swift:6.0-noble-slim

WORKDIR /app

COPY --from=build /workspace/Backend/ClaudeHubRelay/.build/release/ClaudeHubRelay .

EXPOSE 8080

# Use shell form so $PORT gets expanded by the shell
CMD ./ClaudeHubRelay serve --env production --hostname 0.0.0.0 --port ${PORT:-8080}
