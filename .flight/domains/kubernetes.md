# Domain: Kubernetes Design

Kubernetes YAML manifest best practices. Covers security, reliability,
resource management, and operational excellence. Framework-agnostic.


**Validation:** `kubernetes.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings

Add `# flight:ok` comment on the same line to suppress a specific check.
Use sparingly. Document why the suppression is acceptable.

```yaml
# System daemon requiring host network access
hostNetwork: true  # flight:ok
```

```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **Privileged Containers** - Do not run privileged containers. Privileged mode disables most security
mechanisms and grants full host access. Container escape becomes trivial.

   ```
   // BAD
   privileged: true

   // GOOD
   privileged: false
   // GOOD
   securityContext:
     privileged: false
   
   ```

2. **Host Namespace Sharing** - Do not share host namespaces (hostPID, hostIPC, hostNetwork). This breaks
container isolation and allows access to host processes, IPC, and network.

   ```
   // BAD
   hostPID: true
   // BAD
   hostIPC: true
   // BAD
   hostNetwork: true

   // GOOD
   hostPID: false
   // GOOD
   hostNetwork: false
   ```

3. **Dangerous Capabilities** - Do not add dangerous capabilities like SYS_ADMIN, NET_ADMIN, or ALL.
These capabilities enable privilege escalation and container escape.

   ```
   // BAD
   capabilities:
     add: ["SYS_ADMIN"]
   
   // BAD
   capabilities:
     add: ["ALL"]
   

   // GOOD
   capabilities:
     drop: ["ALL"]
     add: ["NET_BIND_SERVICE"]
   
   ```

4. **HostPath Volume Mounts** - Do not mount host filesystem paths. HostPath volumes allow container escape
by accessing sensitive host files like /etc/shadow or Docker socket.

   ```
   // BAD
   volumes:
   - name: docker-sock
     hostPath:
       path: /var/run/docker.sock
   

   // GOOD
   volumes:
   - name: config
     configMap:
       name: app-config
   
   ```

5. **Privilege Escalation Allowed** - Explicitly disable privilege escalation. When allowPrivilegeEscalation is
true or unset, processes can gain more privileges than their parent.

   ```
   // BAD
   allowPrivilegeEscalation: true

   // GOOD
   allowPrivilegeEscalation: false
   ```

6. **Running as Root User** - Do not run containers as root (UID 0). Root inside a container has the
same UID as root on the host, enabling privilege escalation.

   ```
   // BAD
   runAsUser: 0

   // GOOD
   runAsUser: 1000
   // GOOD
   runAsNonRoot: true
   ```

7. **Secrets in Environment Variables** - Do not hardcode secrets in environment variables. Secrets in env vars are
visible in pod specs, logs, and kubectl describe output.

   ```
   // BAD
   env:
   - name: DATABASE_PASSWORD
     value: "secret123"
   

   // GOOD
   env:
   - name: DATABASE_PASSWORD
     valueFrom:
       secretKeyRef:
         name: db-secrets
         key: password
   
   ```

8. **Default ServiceAccount** - Do not use the default ServiceAccount for workloads. The default account
may have excessive permissions. Create dedicated ServiceAccounts.

   ```
   // BAD
   serviceAccountName: default

   // GOOD
   serviceAccountName: my-app-sa
   // GOOD
   automountServiceAccountToken: false
   ```

### MUST (validator will reject)

1. **Container Image Tag Required** - Always specify explicit image tags. Using :latest or no tag causes
unpredictable deployments and makes rollbacks impossible.

   ```
   // BAD
   image: nginx
   // BAD
   image: nginx:latest

   // GOOD
   image: nginx:1.25.3
   // GOOD
   image: nginx@sha256:abc123...
   ```

2. **Resource Requests Required** - Always set resource requests for CPU and memory. Without requests,
the scheduler cannot make informed decisions and autoscaling fails.

   ```
   // BAD
   containers:
   - name: app
     image: myapp:1.0
   

   // GOOD
   containers:
   - name: app
     image: myapp:1.0
     resources:
       requests:
         memory: "128Mi"
         cpu: "100m"
   
   ```

3. **Resource Limits Required** - Always set resource limits for memory. Without limits, a single
misbehaving container can consume all node resources.

   ```
   // BAD
   resources:
     requests:
       memory: "128Mi"
   

   // GOOD
   resources:
     requests:
       memory: "128Mi"
     limits:
       memory: "256Mi"
   
   ```

4. **Liveness Probe Required** - Define liveness probes for long-running containers. Without liveness
probes, Kubernetes cannot detect and restart deadlocked applications.

   ```
   // BAD
   containers:
   - name: app
     image: myapp:1.0
   

   // GOOD
   containers:
   - name: app
     image: myapp:1.0
     livenessProbe:
       httpGet:
         path: /healthz
         port: 8080
       initialDelaySeconds: 30
       periodSeconds: 10
   
   ```

5. **Readiness Probe Required** - Define readiness probes for services. Without readiness probes, traffic
is sent to pods before they're ready, causing errors.

   ```
   // BAD
   containers:
   - name: app
     image: myapp:1.0
   

   // GOOD
   containers:
   - name: app
     image: myapp:1.0
     readinessProbe:
       httpGet:
         path: /ready
         port: 8080
       initialDelaySeconds: 5
       periodSeconds: 5
   
   ```

6. **Deployment Replicas** - Deployments should have at least 2 replicas for high availability.
Single replica deployments have no redundancy during updates or failures.

   ```
   // BAD
   replicas: 1

   // GOOD
   replicas: 2
   // GOOD
   replicas: 3
   ```

7. **Labels Required** - Pods must have standard labels for identification and selection.
Missing labels break service discovery and monitoring.

   ```
   // BAD
   metadata:
     name: my-app
   

   // GOOD
   metadata:
     name: my-app
     labels:
       app.kubernetes.io/name: my-app
       app.kubernetes.io/version: "1.0.0"
   
   ```

8. **Namespace Required** - Specify namespace explicitly. Relying on kubectl context can deploy
to wrong namespace. Never use 'default' namespace for applications.

   ```
   // BAD
   namespace: default
   // BAD
   metadata:
     name: my-app
   

   // GOOD
   metadata:
     name: my-app
     namespace: my-app-prod
   
   ```

### SHOULD (validator warns)

1. **Run as Non-Root** - Set runAsNonRoot: true in securityContext. This provides defense in depth
even if the container image runs as non-root by default.

   ```
   // BAD
   securityContext: {}
   

   // GOOD
   securityContext:
     runAsNonRoot: true
     runAsUser: 1000
   
   ```

2. **Read-Only Root Filesystem** - Set readOnlyRootFilesystem: true. This prevents attackers from modifying
container binaries or installing malware.

   ```
   // BAD
   securityContext:
     runAsNonRoot: true
   

   // GOOD
   securityContext:
     runAsNonRoot: true
     readOnlyRootFilesystem: true
   
   ```

3. **Drop All Capabilities** - Drop all Linux capabilities and only add back what's needed.
By default, containers get several capabilities that are rarely needed.

   ```
   // BAD
   securityContext:
     capabilities: {}
   

   // GOOD
   securityContext:
     capabilities:
       drop: ["ALL"]
       add: ["NET_BIND_SERVICE"]
   
   ```

4. **PodDisruptionBudget Required** - Create PodDisruptionBudgets for critical deployments. PDBs ensure minimum
availability during voluntary disruptions like node drains.

   ```
   // BAD
   # Only Deployment, no PDB
   kind: Deployment
   

   // GOOD
   kind: PodDisruptionBudget
   spec:
     minAvailable: 1
     selector:
       matchLabels:
         app: my-app
   
   ```

5. **Pod Anti-Affinity** - Configure pod anti-affinity to spread replicas across nodes.
Without anti-affinity, all replicas may run on the same node.

   ```
   // BAD
   replicas: 3
   template:
     spec:
       containers: []
   

   // GOOD
   replicas: 3
   template:
     spec:
       affinity:
         podAntiAffinity:
           preferredDuringSchedulingIgnoredDuringExecution:
           - weight: 100
             podAffinityTerm:
               topologyKey: kubernetes.io/hostname
   
   ```

6. **Image Pull Policy Always** - Set imagePullPolicy to Always. This ensures fresh images are pulled
and ImagePullSecrets are always validated.

   ```
   // BAD
   imagePullPolicy: IfNotPresent
   // BAD
   imagePullPolicy: Never

   // GOOD
   imagePullPolicy: Always
   ```

7. **Seccomp Profile** - Configure a Seccomp profile to restrict system calls.
Seccomp significantly reduces the kernel attack surface.

   ```
   // BAD
   securityContext: {}
   

   // GOOD
   securityContext:
     seccompProfile:
       type: RuntimeDefault
   
   ```

8. **Service Account Token Automount** - Disable automatic mounting of ServiceAccount tokens when not needed.
Most applications don't need Kubernetes API access.

   ```
   // BAD
   spec:
     containers: []
   

   // GOOD
   spec:
     automountServiceAccountToken: false
     containers: []
   
   ```

9. **Network Policy** - Create NetworkPolicies to restrict pod-to-pod communication.
By default, all pods can communicate with each other.

   ```
   // BAD
   # Deployment without NetworkPolicy
   

   // GOOD
   kind: NetworkPolicy
   spec:
     podSelector:
       matchLabels:
         app: my-app
     policyTypes:
     - Ingress
     - Egress
   
   ```

10. **Probes Must Differ** - Liveness and readiness probes should not be identical.
Identical probes can cause cascading failures during startup.

   ```
   // BAD
   livenessProbe:
     httpGet:
       path: /health
   readinessProbe:
     httpGet:
       path: /health
   

   // GOOD
   livenessProbe:
     httpGet:
       path: /healthz
     initialDelaySeconds: 30
   readinessProbe:
     httpGet:
       path: /ready
     initialDelaySeconds: 5
   
   ```

### GUIDANCE (not mechanically checked)

1. **Stateless Applications** - Design applications to be stateless where possible. Stateless apps are
easier to scale, update, and recover from failures.


   > Store state in external databases, caches, or object storage.
Use StatefulSets only when truly needed (databases, message queues).

   ```
   // BAD
   Storing session data in container filesystem
   // BAD
   Using local SQLite database

   // GOOD
   Using Redis for session storage
   // GOOD
   Using managed database service
   ```

2. **Horizontal Pod Autoscaler** - Use HorizontalPodAutoscaler for variable workloads. HPA automatically
adjusts replica count based on CPU, memory, or custom metrics.


   > When using HPA, don't set replicas in the Deployment spec.
Configure appropriate min/max replicas and scaling metrics.

   ```
   kind: HorizontalPodAutoscaler
   spec:
     minReplicas: 2
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
   ```

3. **Pod Topology Spread Constraints** - Use topologySpreadConstraints for multi-zone deployments. This ensures
pods are distributed across availability zones for resilience.


   > From Polaris: "The scheduler prefers bin-packing over precise spreading.
Use topologySpreadConstraints to ensure multi-AZ distribution."

   ```
   topologySpreadConstraints:
   - maxSkew: 1
     topologyKey: topology.kubernetes.io/zone
     whenUnsatisfiable: DoNotSchedule
     labelSelector:
       matchLabels:
         app: my-app
   ```

4. **Resource Quality of Service** - Understand QoS classes and configure resources accordingly.
Guaranteed (requests=limits), Burstable, or BestEffort.


   > Critical workloads should use Guaranteed QoS (requests=limits for all
resources). This prevents CPU throttling and OOM kills during pressure.

   ```
   # Guaranteed QoS
   resources:
     requests:
       memory: "256Mi"
       cpu: "500m"
     limits:
       memory: "256Mi"
       cpu: "500m"
   ```

5. **Graceful Shutdown** - Configure preStop hooks and terminationGracePeriodSeconds for graceful
shutdown. This allows in-flight requests to complete.


   > Default terminationGracePeriodSeconds is 30. Increase for long-running
operations. Use preStop hooks to deregister from load balancers.

   ```
   terminationGracePeriodSeconds: 60
   containers:
   - lifecycle:
       preStop:
         exec:
           command: ["/bin/sh", "-c", "sleep 10"]
   ```

6. **Init Containers for Dependencies** - Use init containers to wait for dependencies. This is cleaner than
retry loops in application code.


   > Init containers run sequentially before main containers start.
Use them for database migrations, config fetching, or dependency checks.

   ```
   initContainers:
   - name: wait-for-db
     image: busybox:1.36
     command: ['sh', '-c', 'until nc -z db 5432; do sleep 2; done']
   ```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Privileged containers | privileged: true | Use privileged: false |
| Host namespace sharing | hostNetwork: true | Remove hostPID, hostIPC, hostNetwork |
| Running as root | runAsUser: 0 | Use runAsNonRoot: true, runAsUser: 1000+ |
| Latest image tag | image: nginx:latest | Pin specific version: nginx:1.25.3 |
| Missing resource limits | No resources section | Set requests and limits for CPU/memory |
| Missing probes | No livenessProbe | Configure liveness and readiness probes |
| Single replica | replicas: 1 | Use replicas: 2+ for HA |
| Default namespace | namespace: default | Use dedicated namespace per app |
| Secrets in env vars | env: PASSWORD=secret | Use secretKeyRef or external secrets |
| HostPath volumes | hostPath: /var/run | Use PVC, ConfigMap, or Secret volumes |
