# Docker Guide for Task Master AI

This guide explains how to use Docker with Task Master AI for development and production environments.

## Table of Contents

- [Quick Start](#quick-start)
- [Building Images](#building-images)
- [Running Containers](#running-containers)
- [Docker Compose](#docker-compose)
- [Environment Variables](#environment-variables)
- [Volume Mounts](#volume-mounts)
- [Multi-Stage Builds](#multi-stage-builds)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Using Docker Compose (Recommended)

1. **Copy environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys
   ```

2. **Start the MCP server:**
   ```bash
   docker-compose up task-master-mcp
   ```

3. **Run CLI commands:**
   ```bash
   docker-compose run task-master-cli --help
   docker-compose run task-master-cli list
   ```

4. **Development mode:**
   ```bash
   docker-compose --profile dev up task-master-dev
   ```

### Using Docker Directly

**Build the image:**
```bash
docker build -t task-master-ai:latest .
```

**Run the MCP server:**
```bash
docker run -p 3000:3000 \
  -e ANTHROPIC_API_KEY=your_key \
  task-master-ai:latest
```

**Run CLI commands:**
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  -e ANTHROPIC_API_KEY=your_key \
  task-master-ai:latest \
  node dist/task-master.js list
```

## Building Images

### Multi-Stage Build Targets

The Dockerfile provides several build targets for different use cases:

#### 1. Production (Default)
General production build with all components:
```bash
docker build -t task-master-ai:latest .
# or explicitly:
docker build --target production -t task-master-ai:latest .
```

#### 2. MCP Server
Optimized for running the MCP server:
```bash
docker build --target mcp -t task-master-mcp:latest .
```

#### 3. CLI
Optimized for CLI usage:
```bash
docker build --target cli -t task-master-cli:latest .
```

#### 4. Development
For local development with hot reload:
```bash
docker build --target development -t task-master-dev:latest .
```

### Build Arguments

You can pass build-time arguments if needed:
```bash
docker build \
  --build-arg NODE_VERSION=18 \
  -t task-master-ai:latest .
```

## Running Containers

### MCP Server

**Basic run:**
```bash
docker run -d \
  --name task-master-mcp \
  -p 3000:3000 \
  -e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
  task-master-ai:latest
```

**With volume persistence:**
```bash
docker run -d \
  --name task-master-mcp \
  -p 3000:3000 \
  -v taskmaster-data:/home/taskmaster/.taskmaster \
  -e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
  task-master-ai:latest
```

### CLI Commands

**Initialize a project:**
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  -e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
  task-master-cli:latest init
```

**List tasks:**
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  task-master-cli:latest list
```

**Parse PRD:**
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  -e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
  task-master-cli:latest parse-prd .taskmaster/docs/prd.txt
```

### Development Mode

**With hot reload:**
```bash
docker run -it \
  --name task-master-dev \
  -v $(pwd):/app \
  -v /app/node_modules \
  -p 3000:3000 \
  -p 8080:8080 \
  task-master-dev:latest
```

## Docker Compose

### Services Overview

The `docker-compose.yml` defines three services:

1. **task-master-mcp**: Production MCP server (default profile)
2. **task-master-cli**: CLI service (cli profile)
3. **task-master-dev**: Development service (dev profile)

### Common Commands

**Start services:**
```bash
# Default services (MCP server)
docker-compose up

# In detached mode
docker-compose up -d

# Specific service
docker-compose up task-master-mcp
```

**Run CLI commands:**
```bash
docker-compose run task-master-cli list
docker-compose run task-master-cli next
docker-compose run task-master-cli show 1
```

**Development mode:**
```bash
docker-compose --profile dev up task-master-dev
```

**Stop services:**
```bash
docker-compose down

# Also remove volumes
docker-compose down -v
```

**View logs:**
```bash
docker-compose logs -f task-master-mcp
```

**Rebuild images:**
```bash
docker-compose build
# or force rebuild
docker-compose build --no-cache
```

## Environment Variables

### Required API Keys

At least one AI provider API key is required:

- `ANTHROPIC_API_KEY` - Claude models (recommended)
- `PERPLEXITY_API_KEY` - Research features (recommended)
- `OPENAI_API_KEY` - GPT models
- `GOOGLE_API_KEY` - Gemini models
- `XAI_API_KEY` - Grok models
- `OPENROUTER_API_KEY` - Multiple providers
- `MISTRAL_API_KEY` - Mistral models
- `AZURE_OPENAI_API_KEY` - Azure OpenAI
- `OLLAMA_API_KEY` - Ollama local models

### Setting Environment Variables

**Using .env file (recommended):**
```bash
cp .env.example .env
# Edit .env with your keys
docker-compose up
```

**Using environment file explicitly:**
```bash
docker-compose --env-file .env.production up
```

**Passing directly:**
```bash
docker run -e ANTHROPIC_API_KEY=sk-xxx task-master-ai:latest
```

**Using shell environment:**
```bash
export ANTHROPIC_API_KEY=sk-xxx
docker-compose up
```

## Volume Mounts

### Persistent Data

**Task Master data directory:**
```yaml
volumes:
  - taskmaster-data:/home/taskmaster/.taskmaster
```

**Project files (for CLI):**
```yaml
volumes:
  - ./projects:/workspace
```

**Development source code:**
```yaml
volumes:
  - .:/app
  - /app/node_modules  # Prevent overwriting
  - /app/dist
```

### Example Volume Usage

**Backing up task data:**
```bash
docker run --rm \
  -v taskmaster-data:/data \
  -v $(pwd):/backup \
  alpine \
  tar czf /backup/taskmaster-backup.tar.gz -C /data .
```

**Restoring task data:**
```bash
docker run --rm \
  -v taskmaster-data:/data \
  -v $(pwd):/backup \
  alpine \
  tar xzf /backup/taskmaster-backup.tar.gz -C /data
```

## Multi-Stage Builds

The Dockerfile uses multi-stage builds for optimization:

### Stage Overview

1. **base**: Common dependencies and package files
2. **dependencies**: All dependencies installed
3. **builder**: Source built and compiled
4. **prod-dependencies**: Production-only dependencies
5. **production**: Final production image (minimal)
6. **development**: Development image with dev dependencies
7. **cli**: CLI-optimized image
8. **mcp**: MCP server-optimized image

### Benefits

- **Smaller images**: Production images only contain necessary files
- **Layer caching**: Faster rebuilds with unchanged dependencies
- **Security**: Fewer packages = smaller attack surface
- **Flexibility**: Multiple targets for different use cases

### Image Sizes

Approximate sizes:
- Production: ~200-300MB
- Development: ~500-700MB
- Alpine base: ~100MB less than standard Node images

## Troubleshooting

### Common Issues

#### Permission Errors

If you encounter permission issues:

```bash
# Fix ownership
docker run --rm \
  -v taskmaster-data:/data \
  alpine \
  chown -R 1001:1001 /data
```

#### Port Already in Use

Change the port mapping:
```bash
docker run -p 3001:3000 task-master-ai:latest
# or in docker-compose.yml:
# ports:
#   - "3001:3000"
```

#### Build Failures

Clear build cache and rebuild:
```bash
docker build --no-cache -t task-master-ai:latest .
```

#### Container Doesn't Start

Check logs:
```bash
docker logs task-master-mcp
docker-compose logs task-master-mcp
```

#### Out of Memory

Increase Docker memory limit or use resource constraints:
```bash
docker run -m 2g task-master-ai:latest
```

### Health Checks

Check container health:
```bash
docker ps
# Look for health status in STATUS column

# Detailed health info
docker inspect --format='{{json .State.Health}}' task-master-mcp
```

### Debugging

**Enter running container:**
```bash
docker exec -it task-master-mcp sh
```

**Run with interactive shell:**
```bash
docker run -it --entrypoint sh task-master-ai:latest
```

**Check environment variables:**
```bash
docker exec task-master-mcp env
```

## Best Practices

### Production

1. **Use specific versions**: Pin image versions in production
   ```yaml
   image: task-master-ai:0.33.0
   ```

2. **Resource limits**: Set memory and CPU limits
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '1'
         memory: 2G
   ```

3. **Health checks**: Monitor container health
4. **Logging**: Configure proper log drivers
5. **Secrets**: Use Docker secrets for sensitive data
6. **Updates**: Regularly rebuild images for security patches

### Development

1. **Volume mounts**: Mount source for live reload
2. **Port exposure**: Expose all necessary ports
3. **Environment**: Use separate .env.development
4. **Profiles**: Use docker-compose profiles for dev services

### Security

1. **Non-root user**: Images run as non-root (taskmaster user)
2. **Minimal base**: Alpine images for smaller attack surface
3. **Scan images**: Regularly scan for vulnerabilities
   ```bash
   docker scan task-master-ai:latest
   ```
4. **Update dependencies**: Keep base images and packages updated
5. **Secrets management**: Never commit API keys to images

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Task Master Documentation](https://docs.task-master.dev)
- [Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)

## Contributing

If you encounter issues with the Docker setup or have improvements to suggest, please:

1. Check existing issues: https://github.com/eyaltoledano/claude-task-master/issues
2. Open a new issue with details about your environment
3. Submit a PR with improvements to the Docker configuration

## License

MIT WITH Commons-Clause - See LICENSE file for details
