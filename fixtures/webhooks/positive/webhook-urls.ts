// Webhooks test fixture - SHOULD trigger N7 violations
// Non-HTTPS URL schemes (SSRF risk)

// BAD: file:// scheme can access local files
const fileUrl = 'file:///etc/passwd';

// BAD: ftp:// scheme
const ftpUrl = 'ftp://internal-server/data';

// BAD: gopher:// scheme
const gopherUrl = 'gopher://internal:70/';

// BAD: plain http to external host (not localhost)
const httpUrl = 'http://external-api.com/webhook';

export const webhookUrls = {
  file: fileUrl,
  ftp: ftpUrl,
  gopher: gopherUrl,
  http: httpUrl,
};
