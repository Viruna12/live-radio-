#!/bin/bash

echo "=== Initializing Audio & Video Engine ==="

# 1. Start Virtual Display (1280x720 HD Layout)
Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
sleep 2

# 2. Start PulseAudio Virtual Sink
pulseaudio --start --exit-idle-time=-1
sleep 2
pactl load-module module-null-sink sink_name=VirtualSink sink_properties=device.description=VirtualSink
pactl set-default-sink VirtualSink
export PULSE_SINK=VirtualSink

# 3. Setup Cloudflare WARP if supported
mkdir -p /var/run/dbus
dbus-daemon --system --fork 2>/dev/null || true
warp-svc &
sleep 2
warp-cli --accept-tos registration new 2>/dev/null || true
warp-cli --accept-tos mode proxy 2>/dev/null || true
warp-cli --accept-tos proxy port 40000 2>/dev/null || true
warp-cli --accept-tos connect 2>/dev/null || true
sleep 2

# Check if WARP SOCKS5 Proxy is alive
PROXY_ARG=""
if nc -z 127.0.0.1 40000 2>/dev/null; then
  echo "Cloudflare WARP proxy active on port 40000"
  PROXY_ARG='--proxy-server=socks5://127.0.0.1:40000'
else
  echo "Running direct connection..."
fi

# 4. Launch Clean Chrome in 720p Fullscreen
echo "Launching Google Chrome..."
google-chrome \
  $PROXY_ARG \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-software-rasterizer \
  --no-first-run \
  --disable-extensions \
  --disable-background-networking \
  --autoplay-policy=no-user-gesture-required \
  --window-size=1280,720 \
  --window-position=0,0 \
  --start-fullscreen \
  --kiosk "https://original-site-orpin.vercel.app/?autoplay=1" &

# 5. Wait for YouTube Player and trigger Unmute Clicks
echo "Waiting 12 seconds for page load..."
sleep 12

echo "Unmuting broadcast (Center Click at 640, 360)..."
xdotool search --onlyvisible --class "google-chrome" windowfocus || true
xdotool mousemove 640 360 click 1
sleep 2
xdotool mousemove 640 360 click 1

# 6. Push 24/7 Stream to YouTube Live (128 kbps High Quality Audio)
echo "Starting Live Stream to YouTube (720p Layout @ 128 kbps Audio)..."
ffmpeg -hide_banner -loglevel warning \
  -thread_queue_size 512 -f x11grab -draw_mouse 0 -video_size 1280x720 -framerate 20 -i :99.0 \
  -thread_queue_size 512 -f pulse -i VirtualSink.monitor \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -threads 1 \
  -b:v 180k -maxrate 220k -bufsize 440k -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv "rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_STREAM_KEY}"
