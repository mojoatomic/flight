// Webhooks test fixture - SHOULD trigger N3 and N4 violations
// Unsafe signature comparison

export function verifySignature(signature: string, expected: string): boolean {
  // BAD: Direct string comparison vulnerable to timing attacks (N3)
  if (signature === expected) {
    return true;
  }

  // BAD: Also unsafe comparison (N3)
  const hash = computeHash();
  if (hash == expected) {
    return true;
  }

  // BAD: .equals() method also unsafe (N4)
  const sig = getSignature();
  if (sig.equals(expected)) {
    return true;
  }

  return false;
}

function computeHash(): string {
  return 'abc123';
}

function getSignature(): { equals: (s: string) => boolean } {
  return { equals: (s) => s === 'test' };
}
