# Hardware Inspection Tool

Internal IT tool for Transpro — runs a network speed test and collects hardware info from the employee's machine. Results are sent to a SharePoint list via Power Automate.

**Live URL:** https://orlando-g26.github.io/Hardware-Inspection-tool/
**Repo:** https://github.com/Orlando-G26/Hardware-Inspection-tool

---

## Features

- Network speed test: download, upload, ping, jitter
- Hardware collection: CPU, RAM, OS, model, NIC type & speed
- Multi-platform support: Windows, macOS, Linux, Android, iOS
- Windows: auto-detect via script OR manual entry form
- macOS / Android / iOS: manual entry forms
- Mobile-friendly, branded UI (Trans-Pro colors + Public Sans)
- Three-screen guided flow: Welcome → Setup → Speed Test
- Results submitted to Power Automate → SharePoint

---

## Files

| File | Description | Hosted |
|------|-------------|--------|
| `speedtest-webpage.html` | Main SPA — all UI, logic, and styles | ✅ Yes |
| `run-speedtest.bat` | Windows launcher — self-contained, PS1 embedded as base64 | ✅ Yes |
| `index.html` | Redirect to `speedtest-webpage.html` | ✅ Yes |
| `run-speedtest.ps1` | Windows hardware collector (source reference only — embedded in BAT) | ❌ Not needed |
| `run-speedtest.sh` | Linux hardware collector | ❌ Not needed (macOS is manual entry) |
| `hw-data.js` | Optional hardware data object stub read by the SPA on load | — |
| `security-risks.md` / `.html` | Security vulnerability assessment | — |
| `technical-overview.html` | Full technical documentation: architecture, data flow, APIs, security, roadmap | — |

> **WordPress hosting requires only 3 files:** `speedtest-webpage.html`, `run-speedtest.bat`, `index.html`

---

## Platform Behaviour

| Platform | Method | Data Collected |
|---|---|---|
| Windows (auto) | User runs `run-speedtest.bat` → PS1 collects hardware via WMI/CIM → reopens page with URL params | CPU, RAM, OS build, model, NIC type & speed |
| Windows (manual) | User opens Settings → System → About → fills 4 fields | Model, processor, RAM, Windows version |
| macOS | User opens Apple menu → About This Mac → fills 4 fields | Model, chip, memory, macOS version |
| Linux | User runs `run-speedtest.sh` in Terminal → reopens page with URL params | CPU, RAM, OS, NIC |
| Android | User opens Settings → About Phone → fills 3 fields | Model, Android version, storage |
| iOS | User opens Settings → General → About → fills 3 fields | Model, iOS version, storage |

---

## Windows BAT — How It Works

The BAT file contains the PowerShell script encoded as UTF-16LE base64. On execution:

1. PowerShell decodes the base64 string and writes it to `%TEMP%\transpro-speedtest-<RANDOM>.ps1`
2. PowerShell runs the temp PS1 with `-ExecutionPolicy Bypass`
3. The PS1 queries WMI/CIM for hardware, builds a URL-encoded query string, and opens the browser
4. The temp PS1 is deleted

No internet connection is required during script execution — all data is passed as URL parameters to the page.

---

## Configuration

The only value to update before deploying to a new host is the page URL inside `run-speedtest.ps1` (line 8) and `run-speedtest.sh` (line 5):

```powershell
# run-speedtest.ps1
$sharePointURL = 'https://YOUR-HOST/speedtest-webpage.html'
```

After changing the PS1, re-embed it in the BAT by re-running the base64 encoding step.

The Power Automate webhook URL is set in `speedtest-webpage.html`:

```js
const CONFIG = {
    webhookURL: 'https://...'
};
```

---

## Documentation

- [Security Risk Assessment](security-risks.html) — 9 vulnerabilities with severity ratings and fixes
- [Technical Overview](technical-overview.html) — Full architecture, data flow, API specs, and improvement roadmap

---

## Known Security Issues

See [`security-risks.md`](security-risks.md) for the full assessment. Summary:

| Severity | Issue |
|---|---|
| HIGH | Webhook URL exposed in client source |
| HIGH | No submission authentication |
| HIGH | XSS via `innerHTML` with third-party API data |
| MEDIUM | No rate limiting |
| MEDIUM | No input validation / sanitization |
| MEDIUM | Third-party IP lookup (ipapi.co) |
| LOW | No privacy / consent notice |
| LOW | No HTTPS enforcement |
| LOW | No Content Security Policy |
