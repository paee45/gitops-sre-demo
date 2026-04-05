import React from 'react';

function NavBar({ onLogout }) {
  return (
    <nav className="navbar">
      <div className="navbar-content">
        <div className="navbar-brand">
          <span className="logo">🚀</span>
          <h1>GitOps SRE Demo</h1>
        </div>
        <div className="navbar-links">
          <a href="/" className="nav-link active">Dashboard</a>
          <a href="https://argocd.example.com" target="_blank" rel="noopener noreferrer" className="nav-link">ArgoCD</a>
          <a href="https://grafana.example.com" target="_blank" rel="noopener noreferrer" className="nav-link">Grafana</a>
          <a href="https://kong.example.com" target="_blank" rel="noopener noreferrer" className="nav-link">Kong</a>
          <button onClick={onLogout} className="btn btn-logout">Logout</button>
        </div>
      </div>
    </nav>
  );
}

export default NavBar;
