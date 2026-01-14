# Domain: Docker Design

Dockerfile and container image best practices. Covers security, reproducibility, performance optimization, and maintainability. Framework-agnostic.


**Validation:** `docker.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings



```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // # flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **Running as Root User** - Containers should not run as root. Running as root inside a container means running as root on the host if container escape occurs.

   ```
   // BAD
   # No USER directive at all
   // BAD
   USER root
   // BAD
   USER 0

   // GOOD
   USER appuser
   // GOOD
   USER 1000:1000
   // GOOD
   USER nobody
   ```

2. **Secrets in Build Args or Environment** - Never pass secrets via ARG or ENV. Build args are visible in image history. Environment variables may be logged or exposed. Use secret mounts instead.

   ```
   // BAD
   ARG DB_PASSWORD=secret123
   // BAD
   ENV API_KEY=sk-12345
   // BAD
   ARG PRIVATE_KEY_PATH=/keys/private.pem

   // GOOD
   # Use --secret flag in docker build
   // GOOD
   RUN --mount=type=secret,id=api_key cat /run/secrets/api_key
   // GOOD
   # Pass secrets at runtime, not build time
   ```

3. **ADD for Remote URLs** - Do not use ADD for downloading remote files. ADD with URLs is unpredictable and cannot be verified. Use RUN with curl/wget for checksums and control.

   ```
   // BAD
   ADD https://example.com/file.tar.gz /app/
   // BAD
   ADD http://releases.example.com/v1.0/binary /usr/local/bin/

   // GOOD
   RUN curl -fsSL https://example.com/file.tar.gz | tar xz
   // GOOD
   RUN wget -qO- https://example.com/file.tar.gz | sha256sum -c - && tar xz
   // GOOD
   COPY --from=builder /app/binary /usr/local/bin/
   ```

4. **Privileged Operations in Dockerfile** - Do not configure privileged capabilities in Dockerfile. Capabilities should be granted at runtime with minimal scope, not baked into images.

   ```
   // BAD
   # In docker-compose or run commands baked into image
   // BAD
   RUN setcap cap_net_bind_service+ep /app  # Consider if necessary

   // GOOD
   # Grant capabilities at runtime with docker run --cap-add
   // GOOD
   # Use rootless containers when possible
   ```

5. **Hardcoded Passwords or Keys** - Never hardcode passwords, API keys, or other secrets directly in Dockerfiles. These become permanently visible in image layers and history.

   ```
   // BAD
   ENV password="hunter2"
   // BAD
   RUN echo 'api_key=sk-12345' > /app/config
   // BAD
   ARG token="ghp_xxxxxxxxxxxx"

   // GOOD
   # Use Docker secrets or environment variables at runtime
   // GOOD
   RUN --mount=type=secret,id=password cat /run/secrets/password
   ```

### MUST (validator will reject)

1. **Use Absolute WORKDIR** - WORKDIR must be an absolute path. Relative paths cause confusion and may behave differently depending on previous instructions.

   ```
   // BAD
   WORKDIR app
   // BAD
   WORKDIR ./src
   // BAD
   WORKDIR ../shared

   // GOOD
   WORKDIR /app
   // GOOD
   WORKDIR /home/appuser/src
   // GOOD
   WORKDIR /opt/application
   ```

2. **Pin Base Image Versions** - Always pin base image versions with specific tags or SHA digests. Using 'latest' or no tag causes unpredictable builds and security issues.

   ```
   // BAD
   FROM node
   // BAD
   FROM python:latest
   // BAD
   FROM ubuntu:latest

   // GOOD
   FROM node:20.11.0-alpine3.19
   // GOOD
   FROM python:3.12.1-slim-bookworm
   // GOOD
   FROM ubuntu:22.04@sha256:abc123...
   ```

3. **Use COPY Instead of ADD for Local Files** - Use COPY for copying local files. ADD has implicit behaviors (tar extraction, URL fetching) that make builds unpredictable. Use ADD only for tar extraction.

   ```
   // BAD
   ADD package.json /app/
   // BAD
   ADD src/ /app/src/
   // BAD
   ADD config.yml /etc/app/

   // GOOD
   COPY package.json /app/
   // GOOD
   COPY src/ /app/src/
   // GOOD
   ADD archive.tar.gz /app/  # OK for tar extraction
   ```

4. **MAINTAINER is Deprecated** - MAINTAINER instruction is deprecated. Use LABEL maintainer="..." instead for better metadata handling and OCI compliance.

   ```
   // BAD
   MAINTAINER John Doe <john@example.com>
   // BAD
   MAINTAINER dev-team

   // GOOD
   LABEL maintainer="John Doe <john@example.com>"
   // GOOD
   LABEL org.opencontainers.image.authors="dev-team@example.com"
   ```

5. **Use JSON Notation for CMD and ENTRYPOINT** - Use JSON array format (exec form) for CMD and ENTRYPOINT. Shell form invokes a shell wrapper, preventing proper signal handling and PID 1 issues.

   ```
   // BAD
   CMD node server.js
   // BAD
   ENTRYPOINT /app/entrypoint.sh
   // BAD
   CMD npm start

   // GOOD
   CMD ["node", "server.js"]
   // GOOD
   ENTRYPOINT ["/app/entrypoint.sh"]
   // GOOD
   CMD ["npm", "start"]
   ```

6. **Set SHELL Pipefail Before RUN with Pipes** - When using pipes in RUN commands, set SHELL with pipefail option. Without pipefail, only the exit code of the last command is checked.

   ```
   // BAD
   # No SHELL directive
   RUN curl -fsSL https://example.com/install.sh | bash
   

   // GOOD
   SHELL ["/bin/bash", "-o", "pipefail", "-c"]
   RUN curl -fsSL https://example.com/install.sh | bash
   
   ```

7. **Invalid EXPOSE Port** - EXPOSE must specify valid port numbers (1-65535). Invalid ports indicate configuration errors.

   ```
   // BAD
   EXPOSE 0
   // BAD
   EXPOSE 70000
   // BAD
   EXPOSE 99999

   // GOOD
   EXPOSE 8080
   // GOOD
   EXPOSE 443
   // GOOD
   EXPOSE 3000 5432
   ```

### SHOULD (validator warns)

1. **Pin Package Versions in apt-get** - Pin versions in apt-get install for reproducible builds. Unpinned packages may change between builds, causing subtle breakages.

   ```
   // BAD
   RUN apt-get install -y curl wget
   // BAD
   RUN apt-get install python3

   // GOOD
   RUN apt-get install -y curl=7.88.1-10 wget=1.21.3-1
   // GOOD
   RUN apt-get install python3=3.11.2-6
   ```

2. **Clean Package Cache in Same Layer** - Remove package manager cache in the same RUN layer as install. Cleaning in a separate layer doesn't reduce image size due to layer caching.

   ```
   // BAD
   RUN apt-get update && apt-get install -y curl
   RUN rm -rf /var/lib/apt/lists/*
   

   // GOOD
   RUN apt-get update && apt-get install -y curl \
       && rm -rf /var/lib/apt/lists/*
   
   ```

3. **Use Multi-Stage Builds** - Use multi-stage builds to reduce final image size. Build dependencies should not be included in production images.

   ```
   // BAD
   FROM node:20
   RUN npm install
   RUN npm run build
   CMD ["node", "dist/server.js"]
   

   // GOOD
   FROM node:20 AS builder
   RUN npm install && npm run build
   
   FROM node:20-alpine
   COPY --from=builder /app/dist /app/dist
   CMD ["node", "dist/server.js"]
   
   ```

4. **Order Layers for Caching** - Order Dockerfile instructions from least to most frequently changing. COPY package*.json before COPY . to maximize cache reuse.

   ```
   // BAD
   COPY . /app
   RUN npm install
   

   // GOOD
   COPY package*.json /app/
   RUN npm install
   COPY . /app
   
   ```

5. **Use .dockerignore** - Create a .dockerignore file to exclude unnecessary files from build context. Reduces build time and prevents accidental inclusion of secrets.

   ```
   // BAD
   # No .dockerignore file

   // GOOD
   # .dockerignore
   .git
   node_modules
   __pycache__
   .env
   *.log
   dist
   .DS_Store
   
   ```

6. **Define HEALTHCHECK** - Define HEALTHCHECK instruction for container health monitoring. Enables orchestrators to detect and replace unhealthy containers.

   ```
   // BAD
   FROM node:20
   CMD ["node", "server.js"]
   

   // GOOD
   FROM node:20
   HEALTHCHECK --interval=30s --timeout=3s \
     CMD curl -f http://localhost:3000/health || exit 1
   CMD ["node", "server.js"]
   
   ```

7. **Combine RUN Commands** - Combine related RUN commands to minimize layers. Each RUN creates a new layer, increasing image size and complexity.

   ```
   // BAD
   RUN apt-get update
   RUN apt-get install -y curl
   RUN apt-get install -y wget
   RUN rm -rf /var/lib/apt/lists/*
   

   // GOOD
   RUN apt-get update \
       && apt-get install -y curl wget \
       && rm -rf /var/lib/apt/lists/*
   
   ```

8. **Use Specific COPY Targets** - Avoid COPY . when possible. Copy only required files to improve cache efficiency and reduce unintended file inclusion.

   ```
   // BAD
   COPY . /app

   // GOOD
   COPY package*.json /app/
   COPY src/ /app/src/
   COPY public/ /app/public/
   
   ```

9. **Avoid apt-get upgrade** - Avoid apt-get upgrade/dist-upgrade in Dockerfiles. Upgrading packages can cause unpredictable changes. Pin base images instead.

   ```
   // BAD
   RUN apt-get update && apt-get upgrade -y
   // BAD
   RUN apt-get dist-upgrade

   // GOOD
   # Use a newer base image instead
   // GOOD
   FROM debian:bookworm-20240110
   ```

### GUIDANCE (not mechanically checked)

1. **One Process Per Container** - Each container should run a single process. This enables proper process management, scaling, and logging. Use orchestration for multi-process apps.

   ```
   // BAD
   supervisord managing nginx + app
   // BAD
   Running database and app in same container

   // GOOD
   Separate containers for web, worker, database
   // GOOD
   docker-compose for multi-service orchestration
   ```

2. **Use Official Base Images** - Prefer official images from Docker Hub or verified publishers. Official images are maintained, scanned, and follow best practices.

   ```
   // BAD
   FROM randomuser/node:latest
   // BAD
   FROM unverified-registry.io/base:v1

   // GOOD
   FROM node:20-alpine
   // GOOD
   FROM python:3.12-slim
   // GOOD
   FROM gcr.io/distroless/static-debian12
   ```

3. **Use Labels for Metadata** - Add LABEL instructions for image metadata. Enables image discovery, version tracking, and compliance documentation.

   ```
   // BAD
   # No labels

   // GOOD
   LABEL org.opencontainers.image.title="My App"
   LABEL org.opencontainers.image.version="1.0.0"
   LABEL org.opencontainers.image.source="https://github.com/org/repo"
   
   ```

4. **Prefer Distroless or Alpine** - Use minimal base images (distroless, alpine) for production. Smaller attack surface, fewer vulnerabilities, faster pulls.

   ```
   // BAD
   FROM ubuntu:22.04  # 77MB base
   // BAD
   FROM debian:bookworm  # 124MB base

   // GOOD
   FROM node:20-alpine  # ~50MB
   // GOOD
   FROM gcr.io/distroless/nodejs20-debian12  # ~50MB
   // GOOD
   FROM python:3.12-slim  # ~50MB
   ```

5. **Document Build Arguments** - Document ARG instructions with comments explaining purpose and valid values. Helps maintainers understand build configuration options.

   ```
   // BAD
   ARG VERSION
   ARG ENV
   

   // GOOD
   # Application version for tagging
   ARG VERSION=1.0.0
   # Build environment: development, staging, production
   ARG BUILD_ENV=production
   
   ```

---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| Running as root |  | Add USER directive with non-root user |
| Secrets in image |  | Use --secret mount or runtime environment |
| Unpinned base image |  | Pin specific version: FROM image:x.y.z |
| ADD for local files |  | Use COPY unless extracting tar archives |
| Shell form CMD |  | Use JSON array format for exec form |
| Unclean apt-get |  | Add && rm -rf /var/lib/apt/lists/* in same RUN |
| Poor layer ordering |  | COPY package*.json first, then npm install, then COPY . |
| No multi-stage |  | Use multi-stage builds to separate build and runtime |
| Missing HEALTHCHECK |  | Add HEALTHCHECK instruction |
| Deprecated MAINTAINER |  | Use LABEL maintainer=... |
