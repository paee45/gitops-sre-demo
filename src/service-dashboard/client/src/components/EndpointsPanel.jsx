import React from 'react';

function EndpointsPanel({ endpoints }) {
  if (!endpoints) {
    return (
      <div className="endpoints-panel">
        <h2>🔗 API Endpoints & Quick Links</h2>
        <div className="loading">Loading endpoints...</div>
      </div>
    );
  }

  return (
    <div className="endpoints-panel">
      <h2>🔗 API Endpoints & Quick Links</h2>

      <div className="endpoint-section">
        <h3>Kong API Gateway</h3>
        <div className="endpoint-list">
          <div className="endpoint-item">
            <span className="label">Proxy (port 8000)</span>
            <code>{endpoints.kong.proxy}</code>
            <a href={endpoints.kong.proxy} target="_blank" rel="noopener noreferrer" className="link-icon">↗</a>
          </div>
          <div className="endpoint-item">
            <span className="label">Admin API (port 8001)</span>
            <code>{endpoints.kong.admin}</code>
            <a href={endpoints.kong.admin} target="_blank" rel="noopener noreferrer" className="link-icon">↗</a>
          </div>
          <div className="endpoint-item">
            <span className="label">Prometheus Metrics (port 8100)</span>
            <code>{endpoints.kong.status}</code>
            <a href={endpoints.kong.status} target="_blank" rel="noopener noreferrer" className="link-icon">↗</a>
          </div>
        </div>
      </div>

      <div className="endpoint-section">
        <h3>Services & Dashboards</h3>
        <div className="quick-links-grid">
          <a href={endpoints.services.serviceA} target="_blank" rel="noopener noreferrer" className="quick-link">
            <span className="icon">📨</span>
            <span className="label">Service A API</span>
            <span className="url">{endpoints.services.serviceA}</span>
          </a>
          <a href={endpoints.services.grafana} target="_blank" rel="noopener noreferrer" className="quick-link">
            <span className="icon">📈</span>
            <span className="label">Grafana</span>
            <span className="url">{endpoints.services.grafana}</span>
          </a>
          <a href={endpoints.services.argocd} target="_blank" rel="noopener noreferrer" className="quick-link">
            <span className="icon">🎯</span>
            <span className="label">ArgoCD</span>
            <span className="url">{endpoints.services.argocd}</span>
          </a>
          <a href={endpoints.services.dashboard} target="_blank" rel="noopener noreferrer" className="quick-link">
            <span className="icon">📊</span>
            <span className="label">Dashboard</span>
            <span className="url">{endpoints.services.dashboard}</span>
          </a>
        </div>
      </div>

      <div className="endpoint-section">
        <h3>Kubernetes Debugging</h3>
        <pre className="code-block">
{`# Check cluster status
kubectl cluster-info

# View all pods
kubectl get pods -A

# Service-A logs (with OTEL/metrics)
kubectl logs -n apps -l app=service-a --tail=50 -f

# Kong pod logs
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=50 -f

# Watch ArgoCD sync
kubectl -n argocd exec -it deployment/argocd-server -- \\
  argocd app list

# Exec into service-a pod
kubectl exec -it -n apps deployment/service-a -- /bin/bash`}
        </pre>
      </div>
    </div>
  );
}

export default EndpointsPanel;
