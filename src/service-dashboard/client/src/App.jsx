import React, { useState, useEffect } from 'react';
import axios from 'axios';
import StatusPanel from './components/StatusPanel';
import NavBar from './components/NavBar';
import JWTGenerator from './components/JWTGenerator';
import EndpointsPanel from './components/EndpointsPanel';
import LoadTestPanel from './components/LoadTestPanel';
import './App.css';

function App() {
  const [token, setToken] = useState(localStorage.getItem('dashboard-token') || '');
  const [isAuthenticated, setIsAuthenticated] = useState(!!token);
  const [status, setStatus] = useState(null);
  const [endpoints, setEndpoints] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [inputToken, setInputToken] = useState('');
  const [activeTab, setActiveTab] = useState('status');

  const api = axios.create({
    baseURL: '/api',
    headers: token ? { Authorization: `Bearer ${token}` } : {}
  });

  useEffect(() => {
    if (isAuthenticated && token) {
      // Check health on auth
      api.get('/health')
        .then(() => {
          fetchStatus();
          fetchEndpoints();
        })
        .catch(err => {
          setError('Failed to connect to dashboard API');
          console.error(err);
        });
      
      // Refresh status every 10 seconds
      const interval = setInterval(fetchStatus, 10000);
      return () => clearInterval(interval);
    }
  }, [isAuthenticated, token]);

  const fetchStatus = async () => {
    try {
      setLoading(true);
      const response = await api.get('/status');
      setStatus(response.data);
      setError('');
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to fetch status');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchEndpoints = async () => {
    try {
      const response = await api.get('/endpoints');
      setEndpoints(response.data);
    } catch (err) {
      console.error('Failed to fetch endpoints:', err);
    }
  };

  const handleLogin = (e) => {
    e.preventDefault();
    if (!inputToken.trim()) {
      setError('Please enter a token');
      return;
    }
    setToken(inputToken);
    localStorage.setItem('dashboard-token', inputToken);
    setIsAuthenticated(true);
    setInputToken('');
  };

  const handleLogout = () => {
    setToken('');
    setIsAuthenticated(false);
    localStorage.removeItem('dashboard-token');
    setStatus(null);
    setActiveTab('status');
  };

  if (!isAuthenticated) {
    return (
      <div className="login-container">
        <div className="login-box">
          <h1>📊 GitOps SRE Demo Dashboard</h1>
          <form onSubmit={handleLogin}>
            <div className="form-group">
              <label htmlFor="token">Dashboard Token</label>
              <input
                id="token"
                type="password"
                value={inputToken}
                onChange={(e) => setInputToken(e.target.value)}
                placeholder="Enter dashboard token"
              />
            </div>
            {error && <div className="error-message">{error}</div>}
            <button type="submit" className="btn btn-primary">Login</button>
            <p className="help-text">Default: gitops-sre-demo-token-changeme</p>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="app">
      <NavBar onLogout={handleLogout} />
      
      <div className="tabs-nav">
        <button 
          className={`tab-button ${activeTab === 'status' ? 'active' : ''}`}
          onClick={() => setActiveTab('status')}
        >
          📊 Status
        </button>
        <button 
          className={`tab-button ${activeTab === 'jwt' ? 'active' : ''}`}
          onClick={() => setActiveTab('jwt')}
        >
          🔐 JWT Generator
        </button>
        <button 
          className={`tab-button ${activeTab === 'endpoints' ? 'active' : ''}`}
          onClick={() => setActiveTab('endpoints')}
        >
          🔗 Endpoints
        </button>
        <button 
          className={`tab-button ${activeTab === 'load-test' ? 'active' : ''}`}
          onClick={() => setActiveTab('load-test')}
        >
          ⚡ Load Tests
        </button>
      </div>

      <main className="main-content">
        {error && <div className="error-message">{error}</div>}

        {/* Status Tab */}
        {activeTab === 'status' && (
          <>
            <div className="header">
              <h2>Platform Status Overview</h2>
              <button 
                onClick={fetchStatus} 
                className="btn btn-secondary"
                disabled={loading}
              >
                {loading ? 'Refreshing...' : 'Refresh'}
              </button>
            </div>

            {status && (
              <>
                <div className="status-grid">
                  <StatusPanel
                    title="API Gateway"
                    component="kong"
                    status={status.components.kong}
                    icon="🚪"
                  />
                  <StatusPanel
                    title="Service A"
                    component="service-a"
                    status={status.components['service-a']}
                    icon="🔧"
                  />
                  <StatusPanel
                    title="Service B"
                    component="service-b"
                    status={status.components['service-b']}
                    icon="⚙️"
                  />
                </div>

                <div className="section">
                  <h3>Observability Stack</h3>
                  <div className="status-grid">
                    <StatusPanel
                      title="Grafana"
                      component="grafana"
                      status={status.components.grafana}
                      link="http://localhost:3000"
                      icon="📈"
                    />
                    <StatusPanel
                      title="Loki"
                      component="loki"
                      status={status.components.loki}
                      icon="📝"
                    />
                    <StatusPanel
                      title="Mimir"
                      component="mimir"
                      status={status.components.mimir}
                      icon="💾"
                    />
                    <StatusPanel
                      title="Tempo"
                      component="tempo"
                      status={status.components.tempo}
                      icon="🔍"
                    />
                    <StatusPanel
                      title="Alloy"
                      component="alloy"
                      status={status.components.alloy}
                      icon="🔄"
                    />
                    <StatusPanel
                      title="ArgoCD"
                      component="argocd"
                      status={status.components.argocd}
                      link="http://localhost:8080"
                      icon="🎯"
                    />
                  </div>
                </div>

                <div className="timestamp">
                  Last updated: {new Date(status.timestamp).toLocaleTimeString()}
                </div>
              </>
            )}

            {loading && !status && <div className="loading">Loading status...</div>}
          </>
        )}

        {/* JWT Generator Tab */}
        {activeTab === 'jwt' && (
          <JWTGenerator api={api} />
        )}

        {/* Endpoints Tab */}
        {activeTab === 'endpoints' && (
          <EndpointsPanel endpoints={endpoints} />
        )}

        {/* Load Tests Tab */}
        {activeTab === 'load-test' && (
          <LoadTestPanel api={api} />
        )}
      </main>
    </div>
  );
}

export default App;
