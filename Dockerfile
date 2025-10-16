# syntax=docker/dockerfile:1.7

ARG BUILDKIT_CACHE_MOUNT_NS
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

ARG BUILDKIT_CACHE_MOUNT_NS
ARG CACHE_NS=${BUILDKIT_CACHE_MOUNT_NS:-local}

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

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

FROM python:3.13-slim-bookworm

ARG BUILDKIT_CACHE_MOUNT_NS
ARG CACHE_NS=${BUILDKIT_CACHE_MOUNT_NS:-local}

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv

ENV PATH="/app/.venv/bin:$PATH"

CMD ["python", "-m", "mcp_clickhouse.main"]
