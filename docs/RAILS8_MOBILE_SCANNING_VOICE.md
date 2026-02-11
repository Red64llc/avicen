# Rails 8: Mobile Apps, Camera Scanning & Voice

## Summary

| Capability | Feasibility | Best Approach |
|------------|-------------|---------------|
| **Mobile App** | Excellent | Hotwire Native (iOS/Android) |
| **Camera/Scanning** | Excellent | Bridge Component + Claude Vision |
| **Voice Interaction** | Good | Web Speech API + Stimulus |

All three capabilities are achievable with Rails 8. Here's the detailed research.

---

## Part 1: Rails 8 Web App → Mobile App

You have **three options**, from simplest to most powerful:

### Option A: PWA (Progressive Web App)

**What it is:** Your Rails app runs in the browser but feels like a native app.

**Rails 8 support:** [Built-in by default](https://www.gauravvarma.dev/blog/rails-8-adds-web-push-notifications-and-improved-pwa-support)
- Service worker generated automatically
- Web manifest included
- Push notifications via Action Notifier

**Pros:**
- Zero native code required
- Instant updates (no App Store)
- Works on iOS and Android
- "Add to Home Screen" for app-like experience

**Cons:**
- Limited App Store visibility
- Some iOS PWA limitations (no push notifications until iOS 16.4+, some camera quirks)
- No access to certain native APIs

**Best for:** Quick demos, internal tools, web-first experiences

---

### Option B: Hotwire Native (Recommended)

**What it is:** A thin native shell (Swift/Kotlin) that wraps your Rails web views with native navigation and UI elements.

**Current versions:** [iOS 1.2.2](https://native.hotwired.dev/) (Jul 2025), Android 1.2.5 (Jan 2026)

**How it works:**
```
┌─────────────────────────────────┐
│      Native iOS/Android Shell   │  ← Swift/Kotlin (minimal)
├─────────────────────────────────┤
│         WKWebView/WebView       │
├─────────────────────────────────┤
│      Your Rails HTML/CSS        │  ← Server-rendered
└─────────────────────────────────┘
```

**Key features:**
- [Build once, deploy everywhere](https://blog.humive.com/build-once-run-anywhere-setting-up-hotwire-native-with-rails-for-android-ios/)
- Native navigation (tab bars, back buttons)
- [Bridge Components](https://native.hotwired.dev/overview/bridge-components) for native features (camera, barcode scanner, etc.)
- Ship updates without App Store approval
- Full access to iOS/Android SDKs when needed

**Bridge Components** (formerly Strada):
> "Bridge components enable web features to break out of the web view container and drive native features—whether it's displaying native buttons, native menu sheets, or calling native platform APIs."

**Learning resources:**
- [Official docs](https://native.hotwired.dev/)
- [Hotwire Native for Rails Developers](https://pragprog.com/titles/jmnative/hotwire-native-for-rails-developers/) (Joe Masilotti, Sep 2025)
- [Learn Hotwire course](https://learnhotwire.com/)
- [Rails and Hotwire Codex](https://railsandhotwirecodex.com/)

**Pros:**
- Single Rails codebase for web + mobile
- Native performance and feel
- Progressive enhancement (go native screen-by-screen)
- Strong community (37signals uses this for HEY, Basecamp)

**Cons:**
- Need basic Swift/Kotlin knowledge for bridge components
- App Store submission still required
- Initial setup has a learning curve

**Best for:** Production apps, App Store presence, native-feeling UX

---

### Option C: Capacitor

**What it is:** A cross-platform runtime that wraps any web app in a native container.

**How it differs from Hotwire Native:**
- Hotwire Native: Server-rendered HTML, thin native shell
- Capacitor: Client-side web app bundled into native container

**Pros:**
- Works with any web framework
- Rich plugin ecosystem (camera, filesystem, etc.)
- Can wrap a Rails-powered frontend

**Cons:**
- Less "Rails way" than Hotwire Native
- Requires building frontend assets
- More suited for SPA architectures

**Best for:** If you already have a JavaScript-heavy frontend

---

### Recommendation for Avicen

**Use Hotwire Native** because:
1. You keep your Rails server-rendered views
2. Bridge Components give you native camera access
3. Updates deploy instantly (no App Store wait)
4. Strong fit with Rails 8 philosophy

---

## Part 2: Camera & Document Scanning

### Demo Flow for Prescription Scanning

```
User taps "Scan Prescription"
        ↓
Native camera opens (via Bridge Component)
        ↓
User captures photo
        ↓
Image sent to Rails backend
        ↓
Rails sends to Claude Vision API
        ↓
Extracted data returned to user
        ↓
User confirms/edits before saving
```

### Implementation Options

#### Option 1: Hotwire Native Bridge Component (Best for native app)

Leon Vogt has a [specific tutorial on camera access with Hotwire Native](https://leonvogt.com/camera-access-with-hotwire-native).

**How it works:**

1. **HTML (Stimulus data attributes):**
```html
<div data-controller="bridge--camera"
     data-bridge--camera-callback-value="handlePhoto">
  <button data-action="bridge--camera#capture">
    Scan Prescription
  </button>
</div>
```

2. **Stimulus Controller (JavaScript):**
```javascript
// app/javascript/controllers/bridge/camera_controller.js
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "camera"

  capture() {
    this.send("capture", {}, (result) => {
      // result.imageData contains base64 image
      this.processImage(result.imageData)
    })
  }

  processImage(imageData) {
    // Send to Rails for OCR processing
    fetch('/prescriptions/scan', {
      method: 'POST',
      body: JSON.stringify({ image: imageData })
    })
  }
}
```

3. **Swift Bridge Component (iOS):**
```swift
// CameraComponent.swift
final class CameraComponent: BridgeComponent {
    override class var name: String { "camera" }

    override func onReceive(message: Message) {
        if message.event == "capture" {
            presentCamera()
        }
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        // ... handle photo capture
        // Reply with base64 image data
    }
}
```

**Pre-built option:** There's a [barcode scanner bridge component](https://masilotti.com/bridge-component-library/) available that "scans barcodes and QR codes using a native camera capture." You can adapt this for document capture.

---

#### Option 2: PWA Camera Access (Fallback/web-only)

For PWA or web browser use, you can access the camera directly via JavaScript:

**Simple approach** ([works on mobile](https://daviddalbusco.medium.com/take-photo-and-access-the-picture-library-in-your-pwa-without-plugins-876dc92989b)):
```html
<input type="file" accept="image/*" capture="environment"
       data-controller="photo-capture"
       data-action="change->photo-capture#process">
```

**Advanced approach** (getUserMedia API):
```javascript
// app/javascript/controllers/camera_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "canvas", "preview"]

  async connect() {
    this.stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "environment" } // Back camera
    })
    this.videoTarget.srcObject = this.stream
  }

  capture() {
    const context = this.canvasTarget.getContext('2d')
    context.drawImage(this.videoTarget, 0, 0)
    const imageData = this.canvasTarget.toDataURL('image/jpeg')
    this.sendToServer(imageData)
  }
}
```

**Known iOS PWA issue:** There's a [known bug](https://github.com/mebjas/html5-qrcode/issues/713) where camera won't open in "PWA mode" on iOS. The workaround is using the file input approach or going with Hotwire Native.

---

### OCR Processing with Claude Vision

Once you have the image, send it to Claude for extraction:

```ruby
# app/services/prescription_scanner.rb
class PrescriptionScanner
  def scan(image_base64)
    client = Anthropic::Client.new

    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      messages: [{
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: "image/jpeg",
              data: image_base64
            }
          },
          {
            type: "text",
            text: <<~PROMPT
              Extract the following from this prescription:
              - Medication names
              - Dosages
              - Frequencies (e.g., twice daily, every 8 hours)
              - Duration
              - Doctor name
              - Date

              Return as JSON.
            PROMPT
          }
        ]
      }]
    )

    JSON.parse(response.content.first.text)
  end
end
```

**Alternative: Tesseract.js** (client-side OCR)

For simple text extraction without AI, you can use [Tesseract.js](https://spin.atomicobject.com/text-recognition-tesseract-js/) in the browser:

```javascript
import Tesseract from 'tesseract.js'

Tesseract.recognize(imageData, 'eng')
  .then(({ data: { text } }) => {
    console.log(text)
  })
```

**Recommendation:** Use Claude Vision for prescriptions. It understands medical terminology and can structure the data intelligently, not just extract raw text.

---

## Part 3: Voice Interaction

### Web Speech API

The [Web Speech API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API) provides:
- **Speech Recognition** (speech-to-text)
- **Speech Synthesis** (text-to-speech)

### Browser Support (2025)

| Browser | Support |
|---------|---------|
| Chrome/Edge | Full (via Google servers) |
| Safari | Partial |
| Firefox | Limited |
| iOS Safari | Works in PWA |

**Note:** Chrome sends audio to Google for processing. For privacy, there's an [on-device option](https://www.videosdk.live/developer-hub/stt/javascript-speech-recognition) in newer Chrome versions.

### Stimulus Controller for Voice Commands

```javascript
// app/javascript/controllers/voice_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "transcript"]

  connect() {
    const SpeechRecognition = window.SpeechRecognition ||
                              window.webkitSpeechRecognition

    if (!SpeechRecognition) {
      this.statusTarget.textContent = "Voice not supported"
      return
    }

    this.recognition = new SpeechRecognition()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'

    this.recognition.onresult = (event) => {
      const transcript = event.results[0][0].transcript
      this.transcriptTarget.textContent = transcript

      if (event.results[0].isFinal) {
        this.processCommand(transcript)
      }
    }
  }

  start() {
    this.recognition.start()
    this.statusTarget.textContent = "Listening..."
  }

  stop() {
    this.recognition.stop()
    this.statusTarget.textContent = "Stopped"
  }

  processCommand(transcript) {
    // Parse voice commands
    const lower = transcript.toLowerCase()

    if (lower.includes("took my") || lower.includes("taken")) {
      this.markMedicationTaken(transcript)
    } else if (lower.includes("add prescription")) {
      this.startPrescriptionEntry(transcript)
    } else if (lower.includes("what medications")) {
      this.listMedications()
    }
  }

  markMedicationTaken(transcript) {
    // POST to Rails endpoint
    fetch('/medications/mark_taken', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ voice_input: transcript })
    })
  }
}
```

### Voice Commands for Avicen

| Voice Command | Action |
|---------------|--------|
| "I took my morning medications" | Mark all morning meds as taken |
| "Skip evening dose" | Mark evening meds as skipped |
| "Add prescription for Levothyroxine" | Start prescription entry |
| "What medications do I take today?" | Read today's schedule |
| "What was my last TSH result?" | Read most recent lab value |

### Text-to-Speech for Confirmations

```javascript
speak(text) {
  const utterance = new SpeechSynthesisUtterance(text)
  utterance.rate = 0.9
  utterance.pitch = 1
  window.speechSynthesis.speak(utterance)
}

// Usage
this.speak("Got it! I've marked your morning medications as taken.")
```

---

## Demo-Ready Implementation Order

For maximum demo impact with Rails 8:

### Day 1: Foundation
1. Rails 8 new app with PWA defaults
2. Basic medication model and CRUD
3. Deploy to get HTTPS (required for camera/voice)

### Day 2: Scanning
1. Add simple `<input type="file" capture>` for photos
2. Connect to Claude Vision API
3. Show extracted prescription data

### Day 3: Voice
1. Add voice Stimulus controller
2. Implement "mark as taken" voice command
3. Add voice confirmation responses

### Day 4: Native (optional)
1. Set up Hotwire Native iOS project
2. Add camera bridge component for better UX
3. Submit to TestFlight

---

## Sources

### Hotwire Native
- [Official Documentation](https://native.hotwired.dev/)
- [Hotwire Native for Rails Developers (Book)](https://pragprog.com/titles/jmnative/hotwire-native-for-rails-developers/)
- [Build Once, Run Anywhere Tutorial](https://blog.humive.com/build-once-run-anywhere-setting-up-hotwire-native-with-rails-for-android-ios/)
- [Bridge Components Overview](https://native.hotwired.dev/overview/bridge-components)
- [Camera Access with Hotwire Native](https://leonvogt.com/camera-access-with-hotwire-native)
- [Bridge Component Library](https://masilotti.com/bridge-component-library/)

### Camera & PWA
- [PWA Camera Access Guide (2025)](https://simicart.com/blog/pwa-camera-access/)
- [Take Photos in PWA Without Plugins](https://daviddalbusco.medium.com/take-photo-and-access-the-picture-library-in-your-pwa-without-plugins-876dc92989b)
- [Capacitor Camera Plugin](https://capacitorjs.com/docs/v2/apis/camera)

### OCR
- [Tesseract.js Browser OCR](https://spin.atomicobject.com/text-recognition-tesseract-js/)
- [Rails OCR Tutorial](https://www.toolify.ai/ai-news/extract-text-from-images-with-ocr-ruby-on-rails-7-tutorial-396945)

### Voice
- [Web Speech API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API)
- [JavaScript Speech Recognition 2025](https://www.videosdk.live/developer-hub/stt/javascript-speech-recognition)
- [Voice-Driven Web Apps (Chrome)](https://developer.chrome.com/blog/voice-driven-web-apps-introduction-to-the-web-speech-api)
