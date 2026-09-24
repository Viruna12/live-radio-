FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies, FFmpeg, PulseAudio, Xvfb, dbus
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    ffmpeg \
    pulseaudio \
    pulseaudio-utils \
    xvfb \
    xdotool \
    libasound2-plugins \
    fonts-liberation \
    libnss3 \
    libxss1 \
    libasound2 \
    dbus \
    && rm -rf /var/lib/apt/lists/*

# 1. Install Cloudflare WARP (1.1.1.1) Client
RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" > /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update \
    && apt-get install -y cloudflare-warp \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Google Chrome Stable
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]
