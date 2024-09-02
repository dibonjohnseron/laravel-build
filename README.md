# Laravel Sail Setup Script

A script for setting up a Laravel Sail application with Docker. This script simplifies creating a new Laravel project, configuring it with specified services, and optionally enable a development container and select a specific PHP version.

## Features

- **Project Name**: Specify a name for your Laravel project.
- **Service Configuration**: Choose which services to include with the project.
- **Devcontainer Option**: Optionally enable the development container for a consistent development environment.
- **PHP Version Option**: Optionally specify the PHP version for the runtime.

## Parameters
- `project-name` (required): The name of the Laravel project. It should not contain spaces or symbols other than hyphens.
- `--with services` (optional): Comma-separated list of services to include. Allowed services are: **mysql**, **pgsql**, **mariadb**, **redis**, **memcached**, **meilisearch**, **typesense**, **minio**, **selenium**, **mailpit**. Default includes **mysql**, **redis**, **meilisearch**, **mailpit**, **selenium**.
- `--devcontainer` (optional): Enable the development container for a consistent development environment.
- `--php-version` (optional): Specify PHP version. Supported PHP version runtimes are: **8.0**, **8.1**, **8.2**, **8.3**. Default PHP version is **8.3**.

## Example
To create a Laravel project named my-app with mysql and redis, and enable the development container:
```bash
curl -s https://raw.githubusercontent.com/dibonjohnseron/laravel-build/main/script.sh | bash -s my-app --with mysql,redis --devcontainer
```
To create a Laravel project named my-app with mysql, and php version 8.2:
```bash
curl -s https://raw.githubusercontent.com/dibonjohnseron/laravel-build/main/script.sh | bash -s my-app --with mysql --php-version 8.2
```

## Notes
- Ensure Docker is installed and running before executing the script.
- The script adjusts file permissions to ensure proper access.
