import React, { useState } from 'react';

function JWTGenerator({ api }) {
  const [jwtToken, setJwtToken] = useState('');
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState('');

  const generateJWT = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await api.post('/jwt-generate');
      setJwtToken(response.data.token);
      setCopied(false);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to generate JWT');
    } finally {
      setLoading(false);
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(jwtToken);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="jwt-panel">
      <h2>🔐 JWT Token Generator</h2>
      <p>Generate a demo JWT token for Kong API Gateway testing.</p>
      
      <button 
        onClick={generateJWT} 
        className="btn btn-primary"
        disabled={loading}
      >
        {loading ? 'Generating...' : 'Generate JWT Token'}
      </button>

      {error && <div className="error-message">{error}</div>}

      {jwtToken && (
        <div className="token-box">
          <h3>✅ Token Generated (expires in 1 hour)</h3>
          <div className="token-display">
            <code>{jwtToken}</code>
            <button 
              onClick={copyToClipboard}
              className="btn btn-secondary"
            >
              {copied ? '✓ Copied!' : 'Copy to Clipboard'}
            </button>
          </div>

          <div className="usage-instructions">
            <h4>💡 How to use this token:</h4>
            <pre>
{`# 1. Store the token in a secret
kubectl create secret generic demo-jwt -n tools \\
  --from-literal=token='${jwtToken}' \\
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Use the token to hit Kong
curl -H "Authorization: Bearer ${jwtToken}" \\
  http://localhost:8000/api/orders

# 3. Deploy phase 3 load test
kubectl apply -f demo/load-generator/phase3-kong-ratelimited.yaml`}
            </pre>
          </div>
        </div>
      )}
    </div>
  );
}

export default JWTGenerator;
