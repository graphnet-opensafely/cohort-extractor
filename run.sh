#!/bin/bash
if [[ -z "$1" || "$1" = 'help' || "$1" = '--help' || "$1" = '-help' ]]; then
  echo "./run.sh COMMAND [ARGUMENT]..."
  echo
  echo "Runs COMMAND inside the Docker container with a correctly configured"
  echo "environment. For example:"
  echo
  echo "  Run tests:"
  echo "    ./run.sh pytest"
  echo
  echo "  Start a bash shell:"
  echo "    ./run.sh bash"
  echo
  echo "  Run the cohortextractor tool:"
  echo "    ./run.sh cohortextractor [ARGUMENT]..."
  exit 1
fi

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
docker-compose run \
  --rm \
  -e PYENV_VERSION=3.7.8 \
  -e TPP_DATABASE_URL='mssql://SA:Your_password123!@mssql:1433/Test_OpenCorona' \
  -e EMIS_DATABASE_URL=trino://trino:8080/mssql/dbo \
  -e EMIS_DATASOURCE_DATABASE_URL='mssql://SA:Your_password123!@mssql:1433/Test_EMIS' \
  -e DATABRICKS_DATABASE_URL='jdbc:sqlserver://mssql:1433;databaseName=Test_OpenCorona' \
  app "$@"
