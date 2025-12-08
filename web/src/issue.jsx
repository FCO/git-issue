import React, { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { cachedFetch } from './utils/cache.js'

const owner = 'FCO'
const repo = 'git-issue'

async function fetchCommit(sha) {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/commits/${sha}`)
}

async function fetchTree(sha) {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/trees/${sha}?recursive=1`)
}

async function fetchBlob(sha) {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/git/blobs/${sha}`)
}

async function fetchPathCommits(tipSha, path) {
  return cachedFetch(`https://api.github.com/repos/${owner}/${repo}/commits?sha=${tipSha}&path=${encodeURIComponent(path)}&per_page=100`)
}

function Issue() {
  const { id } = useParams()
  const [title, setTitle] = useState('')
  const [messages, setMessages] = useState([])
  const [error, setError] = useState(null)

  useEffect(() => {
    async function load() {
      try {
        const refRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/git/refs/issues/${id}`, {
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'git-issues-web'
          },
        })
        if (!refRes.ok) throw new Error('Failed to fetch ref')
        const ref = await refRes.json()
        const commitSha = ref.object.sha

        const commit = await fetchCommit(commitSha)
        const treeSha = commit.tree.sha
        const tree = await fetchTree(treeSha)

        const titleEntry = tree.tree.find(e => e.path === 'title')
        const msgsTreeEntry = tree.tree.find(e => e.path === 'msgs')

        if (titleEntry) {
          const blob = await fetchBlob(titleEntry.sha)
          const decoded = atob(blob.content.replace(/\n/g, ''))
          setTitle(decoded)
        }

        let msgs = []
        if (msgsTreeEntry) {
          const msgsTree = await fetchTree(msgsTreeEntry.sha)
          const msgEntries = msgsTree.tree.filter(e => e.type === 'blob')
          msgs = await Promise.all(
            msgEntries.map(async (entry) => {
              const blob = await fetchBlob(entry.sha)
              const content = atob(blob.content.replace(/\n/g, ''))
              const path = entry.path // msgs/<id>
              // Find the first commit that added this file within the issue history
              let author = ''
              try {
                const commits = await fetchPathCommits(commitSha, path)
                if (Array.isArray(commits) && commits.length > 0) {
                  const first = commits[commits.length - 1] // oldest in this page
                  author = first.commit.author?.name || first.author?.login || ''
                }
              } catch {}
              return { id: path.replace(/^msgs\//, ''), content, author }
            })
          )
        }
        setMessages(msgs)
      } catch (e) {
        setError(e.message)
      }
    }
    load()
  }, [id])

  if (error) return <div className="container">Error: {error}</div>

  return (
    <div className="card">
      <div className="section" style={{display:'flex',alignItems:'center',gap:8}}>
        <Link to="/">← Back</Link>
        <span className="badge open">Open</span>
        <h2 style={{margin:0}}>{title || 'Untitled issue'}</h2>
        <span className="meta">{id}</span>
      </div>
      <div className="section">
        <h3>Messages</h3>
        <ul className="list">
          {messages.map(m => (
            <li key={m.id}>
              <div className="meta" style={{marginBottom:8}}>{m.author || m.id}</div>
              <pre>{m.content}</pre>
            </li>
          ))}
        </ul>
      </div>
    </div>
  )
}

export default Issue
