import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { cachedFetch } from './utils/cache.js'

const owner = 'FCO'
const repo = 'git-issue'

async function fetchRefs() {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/matching-refs/issues`)
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
  if (!issues.length) return <div className="container">Loading issues…</div>

  return (
    <div>
      <div className="container">
        <div className="card">
          {issues.map(ref => {
            const id = ref.ref.replace('refs/issues/', '')
            return (
              <div key={ref.ref} className="issue-row">
                <span className="badge open">Open</span>
                <Link className="title" to={`/issue/${id}`}>{id}</Link>
                <span className="meta">{ref.object.sha.slice(0,7)}</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

export default Issues
