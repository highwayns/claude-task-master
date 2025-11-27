#!/usr/bin/env bash
# Task Master AI - Docker Quick Start Script
# This script helps you quickly set up and run Task Master AI with Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check dependencies
check_dependencies() {
    print_header "Checking Dependencies"

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker is installed"

    if ! command -v docker-compose &> /dev/null; then
        print_warning "docker-compose not found, trying docker compose plugin"
        if ! docker compose version &> /dev/null; then
            print_error "Docker Compose is not installed. Please install Docker Compose."
            echo "Visit: https://docs.docker.com/compose/install/"
            exit 1
        fi
        print_success "Docker Compose plugin is available"
        DOCKER_COMPOSE="docker compose"
    else
        print_success "Docker Compose is installed"
        DOCKER_COMPOSE="docker-compose"
    fi
}

# Setup environment
setup_env() {
    print_header "Environment Setup"

    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success "Created .env file from .env.example"
        elif [ -f .env.docker.example ]; then
            cp .env.docker.example .env
            print_success "Created .env file from .env.docker.example"
        else
            print_warning "No .env.example file found, creating basic .env"
            cat > .env << 'EOF'
# Add your API keys here
ANTHROPIC_API_KEY=
PERPLEXITY_API_KEY=
OPENAI_API_KEY=
NODE_ENV=production
EOF
            print_success "Created basic .env file"
        fi

        echo ""
        print_warning "IMPORTANT: Edit .env file and add your API keys!"
        echo "At least one AI provider API key is required."
        echo ""
        read -p "Press Enter after you've added your API keys, or Ctrl+C to exit..."
    else
        print_success ".env file already exists"
    fi

    # Check if API keys are set
    if [ -f .env ]; then
        if ! grep -q "ANTHROPIC_API_KEY=sk-" .env && \
           ! grep -q "OPENAI_API_KEY=sk-" .env && \
           ! grep -q "PERPLEXITY_API_KEY=" .env | grep -v "^#" | grep -q "=."; then
            print_warning "No API keys detected in .env file"
            echo "Make sure to add at least one API key before starting services."
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_success "API keys detected in .env file"
        fi
    fi
}

# Build images
build_images() {
    print_header "Building Docker Images"

    print_info "This may take a few minutes on first run..."

    if $DOCKER_COMPOSE build; then
        print_success "Images built successfully"
    else
        print_error "Failed to build images"
        exit 1
    fi
}

# Start services
start_services() {
    print_header "Starting Services"

    case "$1" in
        mcp|server)
            print_info "Starting MCP server..."
            $DOCKER_COMPOSE up -d task-master-mcp
            print_success "MCP server started"
            print_info "Access at: http://localhost:3000"
            ;;
        dev|development)
            print_info "Starting development server..."
            $DOCKER_COMPOSE --profile dev up task-master-dev
            ;;
        all)
            print_info "Starting all services..."
            $DOCKER_COMPOSE up -d
            print_success "All services started"
            ;;
        *)
            print_info "Starting default services..."
            $DOCKER_COMPOSE up -d
            print_success "Services started"
            ;;
    esac
}

# Show status
show_status() {
    print_header "Service Status"
    $DOCKER_COMPOSE ps

    echo ""
    print_header "Container Health"
    docker ps --filter "name=task-master" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Show logs
show_logs() {
    print_header "Service Logs"
    print_info "Press Ctrl+C to exit logs"
    echo ""
    $DOCKER_COMPOSE logs -f
}

# Run CLI command
run_cli() {
    print_header "Running CLI Command"
    print_info "Command: $@"
    echo ""
    $DOCKER_COMPOSE run --rm task-master-cli "$@"
}

# Stop services
stop_services() {
    print_header "Stopping Services"
    $DOCKER_COMPOSE down
    print_success "Services stopped"
}

# Clean up
cleanup() {
    print_header "Cleaning Up"

    read -p "Remove volumes as well? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $DOCKER_COMPOSE down -v --rmi local
        print_success "Services, volumes, and local images removed"
    else
        $DOCKER_COMPOSE down --rmi local
        print_success "Services and local images removed"
    fi
}

# Show menu
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║        Task Master AI - Docker Setup          ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "1) Quick Start (Build & Run MCP Server)"
    echo "2) Build Images Only"
    echo "3) Start MCP Server"
    echo "4) Start Development Server"
    echo "5) Run CLI Command"
    echo "6) View Service Status"
    echo "7) View Logs"
    echo "8) Stop Services"
    echo "9) Clean Up"
    echo "0) Exit"
    echo ""
}

# Main interactive menu
interactive_mode() {
    while true; do
        show_menu
        read -p "Select an option: " choice
        echo ""

        case $choice in
            1)
                check_dependencies
                setup_env
                build_images
                start_services mcp
                show_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                check_dependencies
                build_images
                read -p "Press Enter to continue..."
                ;;
            3)
                start_services mcp
                show_status
                read -p "Press Enter to continue..."
                ;;
            4)
                start_services dev
                ;;
            5)
                echo "Enter CLI command (e.g., 'list', 'next', '--help'):"
                read -r cmd
                run_cli $cmd
                read -p "Press Enter to continue..."
                ;;
            6)
                show_status
                read -p "Press Enter to continue..."
                ;;
            7)
                show_logs
                ;;
            8)
                stop_services
                read -p "Press Enter to continue..."
                ;;
            9)
                cleanup
                read -p "Press Enter to continue..."
                ;;
            0)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 2
                ;;
        esac
    done
}

# Main script
main() {
    # Parse command line arguments
    case "$1" in
        --quick|-q)
            check_dependencies
            setup_env
            build_images
            start_services mcp
            show_status
            ;;
        --build|-b)
            check_dependencies
            build_images
            ;;
        --start|-s)
            shift
            start_services "$@"
            show_status
            ;;
        --stop)
            stop_services
            ;;
        --status)
            show_status
            ;;
        --logs|-l)
            show_logs
            ;;
        --clean)
            cleanup
            ;;
        --cli)
            shift
            run_cli "$@"
            ;;
        --help|-h)
            echo "Task Master AI - Docker Quick Start"
            echo ""
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --quick, -q          Quick start (build and run)"
            echo "  --build, -b          Build images only"
            echo "  --start, -s [TYPE]   Start services (mcp|dev|all)"
            echo "  --stop               Stop services"
            echo "  --status             Show service status"
            echo "  --logs, -l           Show service logs"
            echo "  --clean              Clean up containers and images"
            echo "  --cli [COMMAND]      Run CLI command"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --quick                    # Quick start with MCP server"
            echo "  $0 --start dev                # Start development server"
            echo "  $0 --cli list                 # Run 'task-master list'"
            echo "  $0 --cli 'show 1'             # Run 'task-master show 1'"
            echo ""
            ;;
        "")
            interactive_mode
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
