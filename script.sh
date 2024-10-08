#!/bin/bash

# Default values
SERVICES="mysql,redis,meilisearch,mailpit,selenium"
DEVCONTAINER=false
PHP_VERSION="8.3"  # Default PHP version

# Allowed services
ALLOWED_SERVICES="mysql pgsql mariadb redis memcached meilisearch typesense minio selenium mailpit phpmyadmin"
# Allowed PHP versions
ALLOWED_PHP_VERSIONS=("8.0" "8.1" "8.2" "8.3")
# phpMyAdmin service configuration
PHPMYADMIN_SERVICE="    phpmyadmin:\n        image: 'phpmyadmin:latest'\n        ports:\n            - 8080:80\n        networks:\n            - sail\n        environment:\n            - PMA_ARBITRARY=1\n"

# Function to display usage
usage() {
  echo "Usage: $0 project-name [--with services] [--devcontainer] [--php-version version]"
  echo "  project-name       Project name (required, no spaces or symbols except hyphens)"
  echo "  --with             Comma-separated list of services (optional, default: mysql,redis,meilisearch,mailpit,selenium)"
  echo "  --devcontainer     Enable --devcontainer option (optional)"
  echo "  --php-version      Specify PHP version (optional, default: $PHP_VERSION)"
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

# Validate services
modify_services() {
    local services="$1"
    local modified_services=""
    
    IFS=',' read -r -a service_array <<< "$services"
    
    for service in "${service_array[@]}"; do
        if [[ "$service" != "phpmyadmin" ]]; then
            modified_services+="$service,"
        fi
    done
    
    # Remove the trailing comma if there are any services left
    modified_services=${modified_services%,}
    
    echo "$modified_services"
}

# Validate PHP version
validate_php_version() {
  local version="$1"
  for allowed in "${ALLOWED_PHP_VERSIONS[@]}"; do
    if [[ "$version" == "$allowed" ]]; then
      return 0
    fi
  done
  echo "Error: Invalid PHP version '$version'. Allowed versions are: ${ALLOWED_PHP_VERSIONS[*]}"
  usage
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
    --php-version)
      PHP_VERSION="$2"
      validate_php_version "$PHP_VERSION"
      shift 2
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

# Run the Laravel Sail command
SAIL_CMD="laravel new $PROJECT_NAME --no-interaction"
docker run --rm \
    --pull=always \
    -v "$(pwd)":/opt \
    -w /opt \
    "laravelsail/php${PHP_VERSION//./}-composer:latest" \
    bash -c "$SAIL_CMD && cd $PROJECT_NAME && php ./artisan sail:install --with=$(modify_services "$SERVICES") $( [ $DEVCONTAINER = true ] && echo '--devcontainer' )"

# Change directory to the project directory
cd "$PROJECT_NAME" || exit

# Pull services and build
if [ "$SERVICES" == "none" ]; then
    ./vendor/bin/sail build
else
    ./vendor/bin/sail pull $(echo $(modify_services "$SERVICES") | tr ',' ' ')
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

# Modify the docker-compose.yml file if a PHP version is specified
if [[ "$PHP_VERSION" ]]; then
    sed -i -E "s|context: ./vendor/laravel/sail/runtimes/[0-9]+\.[0-9]+|context: ./vendor/laravel/sail/runtimes/${PHP_VERSION}|g" "docker-compose.yml"
    sed -i -E "s|image: sail-[0-9]+\.[0-9]+/app|image: sail-${PHP_VERSION}/app|g" "docker-compose.yml"
fi

# Modify the docker-compose.yml file if phpmyadmin is in the list of services
IFS=',' read -r -a service_array <<< "$SERVICES"
for service in "${service_array[@]}"; do
    if [[ "$service" == "phpmyadmin" ]]; then
        awk -v service="$PHPMYADMIN_SERVICE" '
        {
            # Store the line in an array
            lines[NR] = $0
            if ($0 ~ /^networks:/) {
                last_network_line = NR - 1  # Record the line number of the last "networks:"
            }
        }
        END {
            # Output all lines, inserting service before the last "networks:"
            for (i = 1; i <= NR; i++) {
                print lines[i]
                if (i == last_network_line) {
                    printf "%s", service  # Insert the phpmyadmin service before the last "networks:"
                }
            }
        }
        ' "docker-compose.yml" > temp.yml && mv temp.yml "docker-compose.yml"
        break
    fi
done
