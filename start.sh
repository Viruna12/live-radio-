#!/bin/bash

echo "=== Initializing Cloudflare WARP Service ==="

# 1. Start D-Bus & Cloudflare WARP Daemon
mkdir -p /var/run/dbus
dbus-daemon --system --fork 2>/dev/null || true
warp-svc &
sleep 4

# 2. Register & Connect Cloudflare WARP in Proxy Mode
warp-cli --accept-tos registration new 2>/dev/null || true
warp-cli --accept-tos mode proxy 2>/dev/null || true
warp-cli --accept-tos proxy port 40000 2>/dev/null || true
warp-cli --accept-tos connect 2>/dev/null || true
sleep 4

# Wait until WARP port 40000 is open
for i in {1..15}; do
  if nc -z 127.0.0.1 40000 2>/dev/null; then
    echo "✓ Cloudflare WARP is Connected & Listening on 127.0.0.1:40000!"
    break
  fi
  sleep 1
done

# 3. Start Virtual Display
Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
sleep 2

# 4. Start PulseAudio Virtual Sink
pulseaudio --start --exit-idle-time=-1
sleep 2
pactl load-module module-null-sink sink_name=VirtualSink sink_properties=device.description=VirtualSink
pactl set-default-sink VirtualSink
export PULSE_SINK=VirtualSink

# 5. Launch Chrome FORCED THROUGH CLOUDFLARE WARP PROXY
echo "Launching Chrome routed strictly through Cloudflare WARP..."
google-chrome \
  --proxy-server="socks5://127.0.0.1:40000" \
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

# 6. Wait for YouTube Player and trigger Unmute Clicks
echo "Waiting 12 seconds for player initialization..."
sleep 12

echo "Unmuting broadcast..."
xdotool search --onlyvisible --class "google-chrome" windowfocus || true
xdotool mousemove 640 360 click 1
sleep 2
xdotool mousemove 640 360 click 1

# 7. Push 360p Stream to YouTube Live (140k Video + 128k Audio)
echo "Starting Stream to YouTube (360p @ 128 kbps Audio)..."
ffmpeg -hide_banner -loglevel warning \
  -thread_queue_size 512 -f x11grab -draw_mouse 0 -video_size 1280x720 -framerate 20 -i :99.0 \
  -thread_queue_size 512 -f pulse -i VirtualSink.monitor \
  -vf "scale=640:360" \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -threads 1 \
  -b:v 140k -maxrate 160k -bufsize 320k -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv "rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_STREAM_KEY}"
