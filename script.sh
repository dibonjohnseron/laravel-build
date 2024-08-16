#!/bin/bash

# Default values
SERVICES="mysql,redis,meilisearch,mailpit,selenium"
DEVCONTAINER=false

# Allowed services
ALLOWED_SERVICES="mysql pgsql mariadb redis memcached meilisearch typesense minio selenium mailpit"

# Function to display usage
usage() {
  echo "Usage: $0 project-name [--with services] [--devcontainer]"
  echo "  project-name       Project name (required, no spaces or symbols except hyphens)"
  echo "  --with             Comma-separated list of services (optional, default: $SERVICES)"
  echo "  --devcontainer     Enable --devcontainer option (optional)"
  exit 1
}

# Validate services
validate_services() {
  local services="$1"
  IFS=',' read -r -a service_array <<< "$services"
  for service in "${service_array[@]}"; do
    if [[ ! $ALLOWED_SERVICES =~ (^|[[:space:]])$service($|[[:space:]]) ]]; then
      echo "Error: Invalid service '$service'. Allowed services are: $ALLOWED_SERVICES"
      usage
    fi
  done
}

# Parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --with)
      SERVICES="$2"
      validate_services "$SERVICES"
      shift 2
    ;;
    --devcontainer)
      DEVCONTAINER=true
      shift
    ;;
    -*|--*)
      echo "Unknown option $1"
      usage
    ;;
    *)
      POSITIONAL+=("$1") # save positional arg
      shift
    ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Check if project name was provided
if [ -z "${POSITIONAL[0]}" ]; then
  echo "Error: Project name is required."
  usage
fi
PROJECT_NAME="${POSITIONAL[0]}"

# Validate project name: no spaces or symbols except hyphens
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo "Error: Project name must not contain spaces or symbols other than hyphens."
  usage
fi

# Ensure Docker is running
docker info > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Docker is not running."
    exit 1
fi

# Build the Laravel Sail command
SAIL_CMD="laravel new $PROJECT_NAME --no-interaction"
if $DEVCONTAINER; then
  SAIL_CMD="$SAIL_CMD --devcontainer"
fi

# Run the Laravel Sail command
docker run --rm \
    --pull=always \
    -v "$(pwd)":/opt \
    -w /opt \
    laravelsail/php83-composer:latest \
    bash -c "$SAIL_CMD && cd $PROJECT_NAME && php ./artisan sail:install --with=$SERVICES"

cd $PROJECT_NAME

# Pull services and build
if [ "$SERVICES" == "none" ]; then
    ./vendor/bin/sail build
else
    ./vendor/bin/sail pull $(echo $SERVICES | tr ',' ' ')
    ./vendor/bin/sail build
fi

# Set terminal colors
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""

# Adjust permissions and output final message
if sudo -n true 2>/dev/null; then
    sudo chown -R $USER: .
    echo -e "${BOLD}Get started with:${NC} cd $PROJECT_NAME && ./vendor/bin/sail up"
else
    echo -e "${BOLD}Please provide your password so we can make some final adjustments to your application's permissions.${NC}"
    echo ""
    sudo chown -R $USER: .
    echo ""
    echo -e "${BOLD}Thank you! We hope you build something incredible. Dive in with:${NC} cd $PROJECT_NAME && ./vendor/bin/sail up"
fi
