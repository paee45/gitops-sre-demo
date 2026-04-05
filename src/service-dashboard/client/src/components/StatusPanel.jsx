import React from 'react';

function StatusPanel({ title, component, status, link, icon }) {
  const isReady = status?.ready;
  const replicas = status?.replicas || 0;
  const total = status?.total || 0;
  const error = status?.error;

  const statusClass = error ? 'error' : isReady ? 'healthy' : replicas > 0 ? 'degraded' : 'offline';
  const statusText = error ? 'Error' : isReady ? 'Healthy' : replicas > 0 ? `Degraded (${replicas}/${total})` : 'Offline';

  return (
    <div className={`status-card status-${statusClass}`}>
      <div className="card-header">
        <span className="icon">{icon}</span>
        <h4>{title}</h4>
      </div>
      <div className="card-body">
        <div className={`status-badge status-${statusClass}`}>
          {statusText}
        </div>
        {total > 0 && (
          <div className="replicas">
            {replicas}/{total} ready
          </div>
        )}
        {error && (
          <div className="error-text" title={error}>
            {error.substring(0, 40)}...
          </div>
        )}
      </div>
      {link && (
        <div className="card-footer">
          <a href={link} target="_blank" rel="noopener noreferrer" className="link">
            Open → 
          </a>
        </div>
      )}
    </div>
  );
}

export default StatusPanel;
