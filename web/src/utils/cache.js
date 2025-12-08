// Simple cache with ETag support using localStorage
// Stores: { etag, value, cachedAt } keyed by URL

export async function cachedFetch(url, options = {}) {
  const key = url
  const cachedRaw = localStorage.getItem(key)
  let cached = null
  try { cached = cachedRaw ? JSON.parse(cachedRaw) : null } catch {}

  const headers = new Headers(options.headers || {})
  if (cached?.etag) headers.set('If-None-Match', cached.etag)
  headers.set('User-Agent', headers.get('User-Agent') || 'git-issues-web')
  headers.set('Accept', headers.get('Accept') || 'application/vnd.github+json')
  headers.set('X-GitHub-Api-Version', headers.get('X-GitHub-Api-Version') || '2022-11-28')

  const res = await fetch(url, { ...options, headers })

  if (res.status === 304 && cached) {
    // Not modified; return cached value
    return cached.value
  }

  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`Fetch failed (${res.status} ${res.statusText}) ${text}`)
  }

  const etag = res.headers.get('ETag') || null
  const value = await res.json()

  try {
    localStorage.setItem(key, JSON.stringify({ etag, value, cachedAt: Date.now() }))
  } catch {}

  return value
}
