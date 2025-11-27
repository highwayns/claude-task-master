.PHONY: help build build-all build-prod build-cli build-mcp build-dev up down logs clean test

# Variables
IMAGE_NAME := task-master-ai
VERSION := $(shell node -p "require('./package.json').version")
REGISTRY ?=

# Default target
.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo "Task Master AI - Docker Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## build: Build production image
build:
	docker build -t $(IMAGE_NAME):$(VERSION) -t $(IMAGE_NAME):latest .

## build-all: Build all image variants
build-all: build-prod build-cli build-mcp build-dev

## build-prod: Build production image
build-prod:
	docker build --target production -t $(IMAGE_NAME):$(VERSION) -t $(IMAGE_NAME):latest .

## build-cli: Build CLI image
build-cli:
	docker build --target cli -t $(IMAGE_NAME)-cli:$(VERSION) -t $(IMAGE_NAME)-cli:latest .

## build-mcp: Build MCP server image
build-mcp:
	docker build --target mcp -t $(IMAGE_NAME)-mcp:$(VERSION) -t $(IMAGE_NAME)-mcp:latest .

## build-dev: Build development image
build-dev:
	docker build --target development -t $(IMAGE_NAME)-dev:$(VERSION) -t $(IMAGE_NAME)-dev:latest .

## build-no-cache: Build without cache
build-no-cache:
	docker build --no-cache -t $(IMAGE_NAME):$(VERSION) -t $(IMAGE_NAME):latest .

## up: Start services with docker-compose
up:
	docker-compose up -d

## up-dev: Start development services
up-dev:
	docker-compose --profile dev up

## down: Stop all services
down:
	docker-compose down

## down-v: Stop all services and remove volumes
down-v:
	docker-compose down -v

## logs: Show logs from all services
logs:
	docker-compose logs -f

## logs-mcp: Show MCP server logs
logs-mcp:
	docker-compose logs -f task-master-mcp

## logs-dev: Show development server logs
logs-dev:
	docker-compose --profile dev logs -f task-master-dev

## restart: Restart all services
restart: down up

## ps: Show running containers
ps:
	docker-compose ps

## clean: Remove all images and containers
clean:
	docker-compose down -v --rmi all --remove-orphans

## clean-images: Remove all Task Master images
clean-images:
	docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest || true
	docker rmi $(IMAGE_NAME)-cli:$(VERSION) $(IMAGE_NAME)-cli:latest || true
	docker rmi $(IMAGE_NAME)-mcp:$(VERSION) $(IMAGE_NAME)-mcp:latest || true
	docker rmi $(IMAGE_NAME)-dev:$(VERSION) $(IMAGE_NAME)-dev:latest || true

## prune: Clean up unused Docker resources
prune:
	docker system prune -f
	docker volume prune -f

## shell: Open shell in running MCP container
shell:
	docker-compose exec task-master-mcp sh

## shell-cli: Open shell in CLI container
shell-cli:
	docker-compose run --rm --entrypoint sh task-master-cli

## cli: Run CLI command (use CMD="your command")
cli:
	docker-compose run --rm task-master-cli $(CMD)

## test: Run tests in container
test:
	docker run --rm $(IMAGE_NAME)-dev:latest npm test

## test-unit: Run unit tests
test-unit:
	docker run --rm $(IMAGE_NAME)-dev:latest npm run test:unit

## test-integration: Run integration tests
test-integration:
	docker run --rm $(IMAGE_NAME)-dev:latest npm run test:integration

## push: Push images to registry
push:
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY not set. Use: make push REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	docker tag $(IMAGE_NAME):$(VERSION) $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker tag $(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):latest
	docker push $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_NAME):latest

## push-all: Push all image variants to registry
push-all:
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY not set. Use: make push-all REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	docker tag $(IMAGE_NAME):$(VERSION) $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker tag $(IMAGE_NAME):latest $(REGISTRY)/$(IMAGE_NAME):latest
	docker tag $(IMAGE_NAME)-cli:$(VERSION) $(REGISTRY)/$(IMAGE_NAME)-cli:$(VERSION)
	docker tag $(IMAGE_NAME)-cli:latest $(REGISTRY)/$(IMAGE_NAME)-cli:latest
	docker tag $(IMAGE_NAME)-mcp:$(VERSION) $(REGISTRY)/$(IMAGE_NAME)-mcp:$(VERSION)
	docker tag $(IMAGE_NAME)-mcp:latest $(REGISTRY)/$(IMAGE_NAME)-mcp:latest
	docker push $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_NAME):latest
	docker push $(REGISTRY)/$(IMAGE_NAME)-cli:$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_NAME)-cli:latest
	docker push $(REGISTRY)/$(IMAGE_NAME)-mcp:$(VERSION)
	docker push $(REGISTRY)/$(IMAGE_NAME)-mcp:latest

## pull: Pull images from registry
pull:
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY not set. Use: make pull REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	docker pull $(REGISTRY)/$(IMAGE_NAME):$(VERSION)
	docker pull $(REGISTRY)/$(IMAGE_NAME):latest

## scan: Scan image for vulnerabilities
scan:
	docker scan $(IMAGE_NAME):latest || echo "Docker scan not available or failed"

## inspect: Show detailed image information
inspect:
	docker inspect $(IMAGE_NAME):latest

## size: Show image sizes
size:
	@echo "Image sizes:"
	@docker images | grep $(IMAGE_NAME) || echo "No images found"

## backup: Backup Task Master data
backup:
	@mkdir -p ./backups
	docker run --rm \
		-v taskmaster-data:/data \
		-v $(PWD)/backups:/backup \
		alpine \
		tar czf /backup/taskmaster-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz -C /data .
	@echo "Backup created in ./backups/"

## restore: Restore Task Master data (use BACKUP=filename)
restore:
	@if [ -z "$(BACKUP)" ]; then \
		echo "Error: BACKUP not set. Use: make restore BACKUP=taskmaster-backup-YYYYMMDD-HHMMSS.tar.gz"; \
		exit 1; \
	fi
	docker run --rm \
		-v taskmaster-data:/data \
		-v $(PWD)/backups:/backup \
		alpine \
		tar xzf /backup/$(BACKUP) -C /data
	@echo "Backup restored from $(BACKUP)"

## health: Check container health
health:
	@docker ps --filter "name=task-master" --format "table {{.Names}}\t{{.Status}}"

## env-check: Verify environment variables are set
env-check:
	@echo "Checking environment variables..."
	@if [ -f .env ]; then \
		echo "✓ .env file exists"; \
		grep -q "ANTHROPIC_API_KEY" .env && echo "✓ ANTHROPIC_API_KEY set" || echo "✗ ANTHROPIC_API_KEY not set"; \
		grep -q "PERPLEXITY_API_KEY" .env && echo "✓ PERPLEXITY_API_KEY set" || echo "✗ PERPLEXITY_API_KEY not set"; \
	else \
		echo "✗ .env file not found"; \
		echo "Run: cp .env.example .env and add your API keys"; \
	fi

## version: Show version information
version:
	@echo "Task Master AI version: $(VERSION)"
	@echo "Docker version: $$(docker --version)"
	@echo "Docker Compose version: $$(docker-compose --version)"
