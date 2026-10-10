# Enforce HTTPS and minimum TLS on the Cloudflare zone

**Trigger:** when setting up HTTPS enforcement on the asymptora.com zone, or auditing it after a settings change or a new public hostname.

**Prerequisites:** access to the Cloudflare dashboard for the zone; `curl` and `nmap` on a workstation; the list of public hostnames in the zone.

**Owner:** Higor Cazuza.

## Steps

1. **Record the baseline**

   Command:

   ```
   HOSTS="www.asymptora.com asymptora.com blog.asymptora.com blog-admin.asymptora.com"
   for h in $HOSTS; do
     echo "== http://$h/"
     curl -sIL --max-redirs 5 -m 40 "http://$h/" | grep -iE '^(HTTP|location)'
   done
   nmap --script ssl-enum-ciphers -p 443 www.asymptora.com
   ```

   Expected output: any state. Save the output; it is the "before" for the change.

2. **Enable Always Use HTTPS**

   Command: in the dashboard, open SSL/TLS, Edge Certificates, and turn on Always Use HTTPS. Change nothing else in this step.

   Expected output: the setting shows as enabled.

3. **Verify HTTP redirects to HTTPS on every hostname**

   Command: wait one minute, then repeat the loop from step 1.

   Expected output, per hostname:

   ```
   HTTP/1.1 301 Moved Permanently
   Location: https://<hostname>/
   HTTP/2 200
   ```

   The apex adds one more hop (301 to the www hostname) before the final 200. A hostname whose application has no route at `/` ends in 404 instead of 200; the 301 first is what matters.

4. **Verify HTTPS has no redirect loop**

   Command:

   ```
   for h in $HOSTS; do
     echo "== https://$h/"
     curl -sIL --max-redirs 5 -m 40 "https://$h/" | grep -iE '^(HTTP|location)'
   done
   ```

   Expected output: a single final status per hostname and no `Location` lines (except the apex, which redirects to www).

5. **Set the minimum TLS version to 1.2**

   Command: in the dashboard, open SSL/TLS, Edge Certificates, set Minimum TLS Version to TLS 1.2.

   Expected output: the selector shows TLS 1.2.

6. **Verify that TLS 1.0 and 1.1 are refused**

   Command (nmap performs its own handshakes, so the workstation's OpenSSL policy does not affect the result):

   ```
   nmap --script ssl-enum-ciphers -p 443 www.asymptora.com
   nmap --script ssl-enum-ciphers -p 443 blog-admin.asymptora.com
   ```

   Expected output: only `TLSv1.2` and `TLSv1.3` are listed, and `least strength` is `A`.

7. **Verify normal access**

   Command:

   ```
   curl -sI https://www.asymptora.com/ | grep -i '^HTTP'
   ```

   Expected output: `HTTP/2 200`.

## If it fails

- **Redirect loop or `Maximum redirects followed` in step 4:** turn Always Use HTTPS off immediately, then look for an origin-side redirect. Test with `curl`, not a browser, because browsers cache 301 responses.
- **Apex still returns 522 in step 3:** the Redirect Rule pattern may only match HTTPS. Check the rule referenced in the apex ADR.
- **nmap still lists TLS 1.0 or 1.1:** wait a few minutes, confirm the change was saved on the right zone, and repeat.
- **A legitimate client stops connecting after step 5:** set the Minimum TLS Version back to its previous value. The effect is immediate.

## References

- RFC 0003, HTTP security posture (asymptora/www#78)
- The ADR for the apex Redirect Rule
- RFC 8996, deprecation of TLS 1.0 and 1.1
