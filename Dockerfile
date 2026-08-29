FROM python:3.12-slim

# Patch OS packages (clears the openssl/libssl CVE-2026-14456)
RUN apt-get update && apt-get upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN useradd -m appuser

# Patch pip itself before installing deps (clears pip CVEs)
RUN pip install --no-cache-dir --upgrade pip==26.1.2

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
 CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"
CMD ["python", "app.py"]
