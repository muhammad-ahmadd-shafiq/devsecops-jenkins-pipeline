FROM python:3.12-slim AS builder

WORKDIR /app

COPY requirements.txt .

# Patch pip itself before installing deps (clears pip CVEs)
RUN pip install --no-cache-dir --upgrade pip==26.1.2

# Install Flask and dependencies to a separate directory
RUN pip install --prefix=/install -r requirements.txt

FROM python:3.12-slim

# Patch OS packages (clears the openssl/libssl CVE-2026-14456)
RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m appuser

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy application code
COPY . .

# Set proper ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
 CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
