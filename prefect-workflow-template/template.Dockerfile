# ======================================================================
# STUFE 1: Der "Builder"
# ======================================================================
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# WICHTIG: requirements.txt wird hier verwendet
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt


# ======================================================================
# STUFE 2: Das finale, schlanke Image
# ======================================================================
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# Kopiere die venv aus dem Builder
COPY --from=builder /opt/venv /opt/venv

# --- HIER SIND DIE KORREKTUREN ---
# Kopiere die requirements.txt und das .dockerignore explizit
COPY requirements.txt .
COPY .dockerignore .

# Kopiere den Inhalt des src-Ordners direkt nach /app
COPY src/ .

# Pfad zur venv setzen
ENV PATH="/opt/venv/bin:$PATH"