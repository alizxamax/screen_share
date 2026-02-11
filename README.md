# LAN Screen Share (Flutter / FlutLab)

A Flutter app optimized for **very-low-latency local-network screen sharing** with a modern control UI:

- Custom video bitrate
- Output resolution percentage
- Cropping controls (top/bottom/left/right)
- Aspect-ratio presets (including 16:9)
- Audio streaming + audio volume control

## FlutLab notes

- Build mode: **All**
- Recommended primary runtime target for screen sharing: **Android physical device**.
- Uses `flutter_webrtc` display capture and local WebRTC signaling over WebSocket.

## Viewer quick start

1. Start stream in app and copy the WebSocket URL (`ws://PHONE_IP:8920`).
2. Open the viewer page below on another device in the same Wi-Fi.
3. Paste the URL and connect.

```html
<!doctype html>
<html>
  <body style="margin:0;background:#111;color:#fff;font-family:sans-serif;">
    <div style="padding:10px;display:flex;gap:8px;align-items:center;">
      <input id="url" style="width:300px" placeholder="ws://192.168.1.50:8920" />
      <button id="connect">Connect</button>
    </div>
    <video id="v" autoplay playsinline controls style="width:100vw;height:calc(100vh - 60px);object-fit:contain;background:#000"></video>
    <script>
      const video = document.getElementById('v');
      document.getElementById('connect').onclick = async () => {
        const ws = new WebSocket(document.getElementById('url').value);
        const pc = new RTCPeerConnection();
        pc.ontrack = (e) => video.srcObject = e.streams[0];
        pc.onicecandidate = (e) => {
          if (e.candidate) ws.send(JSON.stringify({type:'candidate', ...e.candidate.toJSON()}));
        };
        ws.onmessage = async (evt) => {
          const data = JSON.parse(evt.data);
          if (data.type === 'offer') {
            await pc.setRemoteDescription({type:'offer', sdp:data.sdp});
            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            ws.send(JSON.stringify({type:'answer', sdp:answer.sdp}));
          }
          if (data.type === 'candidate') {
            await pc.addIceCandidate(data);
          }
        };
      }
    </script>
  </body>
</html>
```

## Stability checklist

- Ensure sender and viewer are on the same local network.
- Keep bitrate/resolution balanced for your Wi-Fi quality.
- If startup fails, grant microphone and nearby devices permissions.
