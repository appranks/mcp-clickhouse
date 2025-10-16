# Build stage - Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

ARG CACHE_NS=${BUILDKIT_CACHE_MOUNT_NS:-local}

# Install the project into `/app`
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install git and build dependencies for ClickHouse client
RUN --mount=type=cache,id=${CACHE_NS}-apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=${CACHE_NS}-apt-lib,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends git build-essential

RUN --mount=type=cache,id=${CACHE_NS}-uv-cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=README.md,target=README.md \
    uv sync --locked --no-install-project --no-dev

COPY . /app
RUN --mount=type=cache,id=${CACHE_NS}-uv-cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-editable

# Production stage - Use minimal Python image
FROM python:3.13-slim-bookworm

# Set the working directory
WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /app/.venv /app/.venv

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Run the MCP ClickHouse server by default
CMD ["python", "-m", "mcp_clickhouse.main"]
