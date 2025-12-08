import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { cachedFetch } from './utils/cache.js'

const owner = 'FCO'
const repo = 'git-issue'

async function fetchRefs() {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/matching-refs/issues`)
}

async function fetchCommit(sha) {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/commits/${sha}`)
}
async function fetchTree(sha) {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/trees/${sha}?recursive=1`)
}
async function fetchBlob(sha) {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/blobs/${sha}`)
}

function Issues() {
  const [issues, setIssues] = useState([])
  const [error, setError] = useState(null)

  useEffect(() => {
    fetchRefs()
      .then(data => setIssues(data))
      .catch(err => setError(err.message))
  }, [])

  if (error) return <div className="container">Error: {error}</div>
  if (!issues.length) return <div className="container">No issues found</div>

  return (
    <div>
      <div className="container">
        <div className="card">
          {issues.map(ref => {
            const id = ref.ref.replace('refs/issues/', '')
            const sha = ref.object.sha
            return (
              <IssueRow key={ref.ref} id={id} sha={sha} />
            )
          })}
        </div>
      </div>
    </div>
  )
}

function IssueRow({ id, sha }) {
  const [title, setTitle] = useState('')
  const [hover, setHover] = useState(false)

  useEffect(() => {
    let mounted = true
    ;(async () => {
      try {
        const commit = await fetchCommit(sha)
        const tree = await fetchTree(commit.tree.sha)
        const titleEntry = tree.tree.find(e => e.path === 'title')
        if (titleEntry) {
          const blob = await fetchBlob(titleEntry.sha)
          const decoded = atob(blob.content.replace(/\n/g, ''))
          if (mounted) setTitle(decoded)
        }
      } catch {}
    })()
    return () => { mounted = false }
  }, [sha])

  return (
    <div className="issue-row" onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      <span className="badge open">Open</span>
      <Link className="title" to={`/issue/${id}`}>{title || id}</Link>
      {hover && <span className="meta" title="Issue ID">{id}</span>}
    </div>
  )
}

export default Issues
