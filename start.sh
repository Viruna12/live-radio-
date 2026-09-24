#!/bin/bash

echo "Starting Cloudflare WARP Service..."
# 1. Start D-Bus & Cloudflare WARP Daemon in Background
mkdir -p /var/run/dbus
dbus-daemon --system --fork
warp-svc &
sleep 3

# 2. Configure WARP in SOCKS5 Proxy Mode (Port 40000)
warp-cli --accept-tos registration new || true
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40000
warp-cli --accept-tos connect
sleep 3
echo "Cloudflare WARP is Connected on 127.0.0.1:40000!"

# 3. Start 240p Virtual Display
Xvfb :99 -screen 0 426x240x16 &
export DISPLAY=:99
sleep 2

# 4. Start PulseAudio Virtual Sink
pulseaudio --start --exit-idle-time=-1
sleep 2
pactl load-module module-null-sink sink_name=VirtualSink sink_properties=device.description=VirtualSink
pactl set-default-sink VirtualSink
export PULSE_SINK=VirtualSink

# 5. Launch Chrome ROUTED THROUGH CLOUDFLARE WARP (Bypasses YouTube Bot Block)
echo "Launching Chrome routed through Cloudflare WARP IP..."
google-chrome \
  --proxy-server="socks5://127.0.0.1:40000" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-software-rasterizer \
  --no-first-run \
  --disable-extensions \
  --disable-background-networking \
  --renderer-process-limit=1 \
  --js-flags="--max-old-space-size=48" \
  --autoplay-policy=no-user-gesture-required \
  --window-size=426,240 \
  --window-position=0,0 \
  --start-fullscreen \
  --kiosk "https://original-site-orpin.vercel.app/?autoplay=1" &

# 6. Wait for player & auto unmute click
sleep 8
xdotool search --onlyvisible --class "google-chrome" windowfocus || true
xdotool mousemove 213 120 click 1
sleep 2

# 7. Push 24/7 Stream with 128 kbps High Quality Audio to YouTube Live
echo "Streaming 128 kbps Audio @ 240p 24/7 to YouTube Live..."
ffmpeg -hide_banner -loglevel warning \
  -thread_queue_size 512 -f x11grab -draw_mouse 0 -video_size 426x240 -framerate 12 -i :99.0 \
  -thread_queue_size 512 -f pulse -i VirtualSink.monitor \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -threads 1 \
  -b:v 45k -maxrate 60k -bufsize 120k -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv "rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_STREAM_KEY}"
