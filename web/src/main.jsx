import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Link } from 'react-router-dom'
import Issues from './issues.jsx'
import Issue from './issue.jsx'
import './style.css'

function Header() {
  return (
    <div className="header">
      <div className="container" style={{display:'flex',alignItems:'center',gap:12}}>
        <Link to="/" className="repo">FCO/git-issue</Link>
        <span style={{color:'var(--muted)'}}>Issues</span>
      </div>
    </div>
  )
}

function App() {
  return (
    <BrowserRouter>
      <Header />
      <div className="container">
        <Routes>
          <Route path="/" element={<Issues />} />
          <Route path="/issue/:id" element={<Issue />} />
        </Routes>
      </div>
      <div className="footer">Powered by Git refs over GitHub API</div>
    </BrowserRouter>
  )
}

createRoot(document.getElementById('root')).render(<App />)
