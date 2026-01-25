# Dockerfile with violations

# N1: Running as root (no USER directive)
FROM node:18

# N2: Using latest tag
FROM ubuntu:latest

# N3: Secrets in ENV
ENV DATABASE_PASSWORD=secret123
ENV API_KEY=abc123

# N4: ADD instead of COPY for local files
ADD ./src /app/src

# N5: apt-get without cleanup
RUN apt-get update && apt-get install -y curl

# M1: No WORKDIR set
COPY . .

# Running as root implicitly
CMD ["node", "server.js"]
