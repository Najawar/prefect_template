# ===========================
# STAGE 1: Builder
# ===========================
FROM python:3.11-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# nur requirements kopieren, um Cache optimal zu nutzen
COPY requirements.txt .

# Wheels bauen (offline-freundlich)
RUN python -m pip install --upgrade pip wheel && \
    pip wheel --wheel-dir /build/wheels -r requirements.txt

# ===========================
# STAGE 2: Runtime
# ===========================
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# venv anlegen (leichtgewichtiger als systemweit)
ENV VIRTUAL_ENV=/opt/venv
RUN python -m venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /app

# vorgebaute Wheels + install
COPY --from=builder /build/wheels /wheels
RUN pip install --no-index --find-links=/wheels /wheels/* && rm -rf /wheels

# nur Applikationscode kopieren
# (achte darauf, dass dein .dockerignore groß ist: venv, .git, __pycache__ etc.)
COPY src /app/src

# Optional: macht "import <dein paket>" aus src/ möglich
ENV PYTHONPATH="/app/src:${PYTHONPATH}"

# Falls du eine CLI startest, hier definieren:
# CMD ["python", "-m", "your_package.main"]
