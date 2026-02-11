# LAN Screen Share (Flutter / FlutLab)

A Flutter app for **low-latency local-network screen sharing** with configurable quality controls:

- Custom video bitrate
- Output resolution percentage
- Crop controls (top / bottom / left / right)
- Aspect-ratio presets (16:9, 9:16, 4:3, 1:1, 21:9)
- Audio capture (where platform supports it) + audio volume control

## FlutLab target

- Build mode: **All**
- Best runtime target for screen capture: **Android physical device**
- Streaming transport: WebRTC + local WebSocket signaling (`ws://PHONE_IP:8920`)

## Important stability notes

1. Screen capture APIs differ by platform and OS version.
2. `resizeMode: crop-and-scale` + aspect ratio is requested for encoder-side framing.
3. Explicit per-edge crop values are validated and displayed in status so you can confirm the applied profile.
4. Crop is applied on the video track when platform WebRTC supports edge-crop constraints; otherwise the app falls back to framed resize (`crop-and-scale`) and reports that fallback in stream status.


## GitHub build/merge requirements

A GitHub Actions workflow is included at `.github/workflows/dart.yml` (runs on `main`/`master`/`work` pushes and all pull requests) and runs:

- `flutter pub get`
- `flutter analyze`
- `flutter test`

This is intended to satisfy protected-branch merge requirements once pushed to GitHub.

This avoids the common CI failure from running `dart pub get` on Flutter projects.

## Build checklist (FlutLab)

1. Import this repository into FlutLab GitHub project.
2. Run `pub get`.
3. Build Android first (`APK` or `AAB`) to validate permissions and capture flow.
4. On first launch, allow microphone permission.

## Viewer quick start

1. Start stream in app and copy the WebSocket URL (`ws://PHONE_IP:8920`).
2. Open the viewer page below on another device in the same Wi-Fi.
3. Paste URL and connect.

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
      };
    </script>
  </body>
</html>
```
