import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import dotenv from 'dotenv';
import crypto from 'crypto';
import YAML from 'js-yaml';
import * as k8s from '@kubernetes/client-node';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = process.env.PORT || 3000;
const DASHBOARD_TOKEN = process.env.DASHBOARD_TOKEN || 'gitops-sre-demo-token-changeme';

// Middleware
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// Auth middleware
const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token !== DASHBOARD_TOKEN) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
};

// Initialize Kubernetes client
const kc = new k8s.KubeConfig();
kc.loadFromDefault();
const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const customApi = kc.makeApiClient(k8s.CustomObjectsApi);
const appsApi = kc.makeApiClient(k8s.AppsV1Api);

// Health check endpoint (no auth required)
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Status endpoint
app.get('/api/status', authMiddleware, async (req, res) => {
  try {
    const status = {
      timestamp: new Date().toISOString(),
      components: {
        kong: { ready: false, replicas: 0 },
        'service-a': { ready: false, replicas: 0 },
        'service-b': { ready: false, replicas: 0 },
        argocd: { ready: false, replicas: 0 },
        grafana: { ready: false, replicas: 0 },
        loki: { ready: false, replicas: 0 },
        mimir: { ready: false, replicas: 0 },
        tempo: { ready: false, replicas: 0 },
        alloy: { ready: false, replicas: 0 }
      }
    };

    // Check Kong
    try {
      const kongDeploy = await appsApi.readNamespacedDeployment('kong-kong', 'kong');
      status.components.kong = {
        ready: kongDeploy.body.status.readyReplicas === kongDeploy.body.spec.replicas,
        replicas: kongDeploy.body.status.readyReplicas || 0,
        total: kongDeploy.body.spec.replicas
      };
    } catch (e) {
      status.components.kong.error = e.message;
    }

    // Check services in apps namespace
    for (const service of ['service-a', 'service-b']) {
      try {
        const deploy = await appsApi.readNamespacedDeployment(service, 'apps');
        status.components[service] = {
          ready: deploy.body.status.readyReplicas === deploy.body.spec.replicas,
          replicas: deploy.body.status.readyReplicas || 0,
          total: deploy.body.spec.replicas
        };
      } catch (e) {
        status.components[service].error = e.message;
      }
    }

    // Check observability stack
    const observabilityNamespace = 'observability';
    for (const comp of ['argocd', 'grafana', 'loki', 'mimir', 'tempo', 'alloy']) {
      try {
        // Try deployment first
        let deploy;
        if (comp === 'alloy') {
          deploy = await appsApi.readNamespacedDaemonSet(comp, observabilityNamespace);
          const desired = deploy.body.status.desiredNumberScheduled || 0;
          const ready = deploy.body.status.numberReady || 0;
          status.components[comp] = { ready: desired === ready, replicas: ready, total: desired };
        } else {
          deploy = await appsApi.readNamespacedDeployment(comp, observabilityNamespace);
          status.components[comp] = {
            ready: deploy.body.status.readyReplicas === deploy.body.spec.replicas,
            replicas: deploy.body.status.readyReplicas || 0,
            total: deploy.body.spec.replicas
          };
        }
      } catch (e) {
        status.components[comp].error = e.message;
      }
    }

    res.json(status);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Kong metrics endpoint
app.get('/api/kong-metrics', authMiddleware, async (req, res) => {
  try {
    // Get Kong service NodePort
    const kongService = await k8sApi.readNamespacedService('kong-kong-proxy', 'kong');
    const nodePort = kongService.body.spec.ports.find(p => p.port === 8000)?.nodePort;
    if (!nodePort) {
      return res.status(404).json({ error: 'Kong NodePort not found' });
    }
    res.json({
      proxyPort: 8000,
      nodePort,
      statusPort: 8100,
      metricsUrl: `http://localhost:${nodePort}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// List namespace pods
app.get('/api/pods/:namespace', authMiddleware, async (req, res) => {
  try {
    const pods = await k8sApi.listNamespacedPod(req.params.namespace);
    const podList = pods.body.items.map(pod => ({
      name: pod.metadata.name,
      status: pod.status.phase,
      restarts: pod.status.containerStatuses?.reduce((sum, cs) => sum + cs.restartCount, 0) || 0,
      ready: pod.status.containerStatuses?.filter(cs => cs.ready).length || 0,
      total: pod.status.containerStatuses?.length || 0
    }));
    res.json(podList);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Generate JWT for Kong demo
app.post('/api/jwt-generate', authMiddleware, (req, res) => {
  try {
    const jwtSecret = 'gitops-sre-demo-jwt-secret-changeme';
    
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
    
    const payload = Buffer.from(JSON.stringify({
      iss: 'demo-client',
      exp: Math.floor(Date.now() / 1000) + 3600
    }))
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
    
    const msg = `${header}.${payload}`;
    const sig = crypto
      .createHmac('sha256', jwtSecret)
      .update(msg)
      .digest('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
    
    const token = `${msg}.${sig}`;
    res.json({ token, expiresIn: 3600 });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Deploy load generator job
app.post('/api/deploy-load-test/:phase', authMiddleware, async (req, res) => {
  try {
    const phase = req.params.phase;
    if (!['phase1', 'phase2', 'phase3'].includes(phase)) {
      return res.status(400).json({ error: 'Invalid phase. Use: phase1, phase2, or phase3' });
    }
    
    // Read and apply the load generator Job
    // In a real deployment, this would read from the cluster or GitHub
    // For demo, just return a command the user can run
    res.json({
      message: `To deploy ${phase} load test, run:`,
      command: `kubectl apply -f demo/load-generator/${phase}-*.yaml`,
      pods: `kubectl get pods -l job-name=load-${phase} -n tools`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get Kong proxy URL and endpoints
app.get('/api/endpoints', authMiddleware, async (req, res) => {
  try {
    const nodes = await k8sApi.listNode();
    const node = nodes.body.items[0];
    const nodeIP = node.status.addresses.find(addr => addr.type === 'ExternalIP' || addr.type === 'InternalIP')?.address || 'localhost';
    
    res.json({
      kong: {
        proxy: `http://${nodeIP}:8000`,
        admin: `http://${nodeIP}:8001`,
        status: `http://${nodeIP}:8100/metrics`
      },
      services: {
        serviceA: `http://${nodeIP}:8000/api/orders`,
        grafana: `http://${nodeIP}:3000`,
        argocd: `http://${nodeIP}:32080`,
        dashboard: `http://${nodeIP}:8090`
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Serve React frontend
app.use(express.static(path.join(__dirname, 'client/dist')));
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'client/dist/index.html'));
});

// Start server
app.listen(PORT, () => {
  console.log(`[service-dashboard] Server running on port ${PORT}`);
  console.log(`[service-dashboard] Dashboard token: ${DASHBOARD_TOKEN}`);
  console.log(`[service-dashboard] Visit http://localhost:${PORT}`);
});
