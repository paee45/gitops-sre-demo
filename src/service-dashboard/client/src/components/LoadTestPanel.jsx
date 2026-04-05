import React, { useState } from 'react';

function LoadTestPanel({ api }) {
  const [selectedPhase, setSelectedPhase] = useState('phase1');
  const [phaseOutput, setPhaseOutput] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const deployPhase = async (phase) => {
    try {
      setLoading(true);
      setError('');
      const response = await api.post(`/deploy-load-test/${phase}`);
      setPhaseOutput(response.data);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to deploy load test');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="load-test-panel">
      <h2>⚡ Kong Load Test Demo</h2>
      <p>Run the 3-phase Kong demonstration to show API gateway protection in action.</p>

      <div className="phases-grid">
        <div className="phase-card">
          <h3>Phase 1: Direct Attack</h3>
          <p className="description">
            🎯 Baseline: 500 concurrent requests hit service-a directly with no Kong protection.
          </p>
          <ul className="phase-info">
            <li>❌ No JWT validation</li>
            <li>❌ No rate limiting</li>
            <li>⚠️ Service error rate spikes</li>
            <li>📊 Watch Deployment Health dashboard</li>
          </ul>
          <button
            onClick={() => {
              setSelectedPhase('phase1');
              deployPhase('phase1');
            }}
            className="btn btn-primary"
            disabled={loading}
          >
            {loading && selectedPhase === 'phase1' ? 'Deploying...' : 'Deploy Phase 1'}
          </button>
        </div>

        <div className="phase-card">
          <h3>Phase 2: Authentication</h3>
          <p className="description">
            🛡️ Same flood, but through Kong without a valid JWT token.
          </p>
          <ul className="phase-info">
            <li>✅ JWT validation active</li>
            <li>✅ 100% 401 Unauthorized</li>
            <li>✅ Service-A receives ZERO requests</li>
            <li>📊 Check Kong Traffic dashboard</li>
          </ul>
          <button
            onClick={() => {
              setSelectedPhase('phase2');
              deployPhase('phase2');
            }}
            className="btn btn-primary"
            disabled={loading}
          >
            {loading && selectedPhase === 'phase2' ? 'Deploying...' : 'Deploy Phase 2'}
          </button>
        </div>

        <div className="phase-card">
          <h3>Phase 3: Rate Limiting</h3>
          <p className="description">
            🚦 With a valid JWT, rate limit preserves SLOs under attack.
          </p>
          <ul className="phase-info">
            <li>✅ JWT validation passes</li>
            <li>✅ First 60 req/min = 200 OK</li>
            <li>✅ Remainder = 429 Too Many Requests</li>
            <li>📊 Service-A P95 latency unaffected</li>
          </ul>
          <button
            onClick={() => {
              setSelectedPhase('phase3');
              deployPhase('phase3');
            }}
            className="btn btn-primary"
            disabled={loading}
          >
            {loading && selectedPhase === 'phase3' ? 'Deploying...' : 'Deploy Phase 3'}
          </button>
        </div>
      </div>

      {error && <div className="error-message">{error}</div>}

      {phaseOutput && (
        <div className="phase-output">
          <h3>Command to run:</h3>
          <pre className="code-block">{phaseOutput.command}</pre>
          <h3>Monitor pods:</h3>
          <pre className="code-block">{phaseOutput.pods}</pre>
        </div>
      )}

      <div className="demo-guide">
        <h3>📋 Full Demo Walkthrough</h3>
        <ol className="step-list">
          <li>
            <strong>Verify readiness:</strong>
            <pre>kubectl wait --for=condition=ready pod -l app=service-a -n apps --timeout=60s</pre>
          </li>
          <li>
            <strong>Go to JWT Generator tab</strong> and generate a token for Phase 3
          </li>
          <li>
            <strong>Deploy Phase 1</strong> (direct attack) — watch error rate spike in Grafana
          </li>
          <li>
            <strong>Deploy Phase 2</strong> (no auth) — watch 401s in Kong Traffic dashboard
          </li>
          <li>
            <strong>Deploy Phase 3</strong> (rate limited) — watch 429s, P95 latency stays stable
          </li>
          <li>
            <strong>Check SLO gauges</strong> — all green despite attack traffic
          </li>
        </ol>
      </div>

      <div className="grafana-dashboards">
        <h3>📊 Key Grafana Dashboards</h3>
        <div className="dashboard-links">
          <a href="http://localhost:3000/d/deployment-health" target="_blank" rel="noopener noreferrer" className="dashboard-link">
            Deployment Health (SLO gauges)
          </a>
          <a href="http://localhost:3000/d/kong-traffic" target="_blank" rel="noopener noreferrer" className="dashboard-link">
            Kong Traffic & Protection (401/429/5xx)
          </a>
          <a href="http://localhost:3000/d/go-processes" target="_blank" rel="noopener noreferrer" className="dashboard-link">
            Go RED Metrics (service-a/b)
          </a>
        </div>
      </div>
    </div>
  );
}

export default LoadTestPanel;
