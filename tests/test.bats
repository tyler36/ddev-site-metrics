#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=tyler36/ddev-site-metrics

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  grafana_health_check
  prometheus_health_check
  grafana_loki_health_check
  alloy_health_check
  tempo_health_check
}

grafana_health_check() {
  # Test the Grafana main page is accessible
  run curl -sf "https://${PROJNAME}.ddev.site:3000"
  assert_output --partial "<title>Grafana</title>"
}

prometheus_health_check() {
  # Test the Prometheus API is available
  run curl -sf "https://${PROJNAME}.ddev.site:9090/api/v1/status/config"
  assert_output --partial '"status":"success"'

  # Test Prometheus exposes metrics
  run curl -sf "https://${PROJNAME}.ddev.site:9090/metrics"
  assert_output --partial 'TYPE prometheus_build_info'
}

grafana_loki_health_check() {
  # Test Grafana Loki exposes metrics
  run ddev exec curl -sf "grafana-loki:3100/metrics"
  assert_output --partial "HELP loki_build_info"
}

alloy_health_check() {
  # Attempt to reload alloy configuration to prove the site is functioning.
  run ddev alloy -r
  assert_output --partial config reloaded
}

tempo_health_check() {
  run ddev exec curl -sf "tempo:3200/metrics"
  assert_output --partial "HELP tempo_build_info"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  health_checks
}

@test "Grafana port is configurable" {
  set -eu -o pipefail

  export GRAFANA_HTTPS_PORT=3043

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  ddev dotenv set .ddev/.env --grafana-https-port="${GRAFANA_HTTPS_PORT}"
  run ddev restart -y
  assert_success

  run curl -sf "https://${PROJNAME}.ddev.site:${GRAFANA_HTTPS_PORT}"
  assert_output --partial "<title>Grafana</title>"
}

@test "Grafana is pre-configured with datasources" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  # Query Grafana API for Prometheus datasource
  run curl -sf "https://${PROJNAME}.ddev.site:3000/api/datasources/uid/prometheus"
  assert_output --partial '"name":"Prometheus"'
  assert_output --partial '"url":"http://prometheus:9090"'

  # Query Grafana API for Tempo datasource
  run curl -sf "https://${PROJNAME}.ddev.site:3000/api/datasources/uid/tempo"
  assert_output --partial '"name":"Tempo"'
  assert_output --partial '"url":"http://tempo:3200"'
}

@test "Grafana is pre-configured with DDEV MySQL datasource" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  # Query Grafana API for MySQL datasource
  run curl -sf "https://${PROJNAME}.ddev.site:3000/api/datasources/uid/mysql"
  assert_output --partial '"name":"MySQL"'
  assert_output --partial '"url":"db:3306"'
  assert_output --partial '"database":"db"'
  assert_output --partial '"user":"db"'
}

@test "Grafana is pre-configured with DDEV Postgres datasource" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  # Query Grafana API for Postgres datasource
  run curl -sf "https://${PROJNAME}.ddev.site:3000/api/datasources/uid/postgres"
  assert_output --partial '"name":"Postgres"'
  assert_output --partial '"url":"db:5432"'
  assert_output --partial '"database":"db"'
  assert_output --partial '"user":"db"'
}

@test "Prometheus port is configurable" {
  set -eu -o pipefail

  export PROMETHEUS_HTTPS_PORT=9043

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  ddev dotenv set .ddev/.env --prometheus-https-port="${PROMETHEUS_HTTPS_PORT}"
  run ddev restart -y
  assert_success

  # Test the Prometheus API is available
  run curl -sf "https://${PROJNAME}.ddev.site:${PROMETHEUS_HTTPS_PORT}/api/v1/status/config"
  assert_output --partial '"status":"success"'

  # Test Prometheus exposes metrics
  run curl -sf "https://${PROJNAME}.ddev.site:${PROMETHEUS_HTTPS_PORT}/metrics"
  assert_output --partial 'TYPE prometheus_build_info'
}

@test "Nginx metrics are exposed" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  export TARGET_METRIC='nginx_exporter_build_info'

  # Check it exposes endpoint with statistics
  run ddev exec curl -vs nginx-exporter:9113/metrics
  assert_output --partial "HELP ${TARGET_METRIC}"

  # Prometheus receives metrics
  run curl -sf "https://${PROJNAME}.ddev.site:9090/api/v1/metadata"
  assert_output --partial "${TARGET_METRIC}"
}

@test "MySQL metrics are exposed" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  export TARGET_METRIC='mysql_up'

  # Check it exposes endpoint with statistics
  run ddev exec curl -vs mysql-exporter:9104/metrics
  assert_output --partial "HELP ${TARGET_METRIC}"

  # Prometheus receives metrics
  run curl -sf "https://${PROJNAME}.ddev.site:9090/api/v1/metadata"
  assert_output --partial "${TARGET_METRIC}"
}

@test "Postgres metrics are exposed" {
  set -eu -o pipefail

  echo "# Convert project to Postgres" >&3
  ddev delete -Oy
  ddev config --database=postgres:16

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  export TARGET_METRIC='postgres_exporter_build_info'

  # Check it exposes endpoint with statistics
  run ddev exec curl -vs postgres-exporter:9187/metrics
  assert_output --partial "HELP ${TARGET_METRIC}"

  # Prometheus receives metrics
  run curl -sf "https://${PROJNAME}.ddev.site:9090/api/v1/metadata"
  assert_output --partial "${TARGET_METRIC}"
}

@test "It only installs one database type" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  # Assert 'mysql-exporter' files exist.
  assert_file_exists .ddev/docker-compose.mysql-exporter.yaml
  assert_file_exists .ddev/grafana/dashboards/mysql.json
  # Assert 'postgres-exporter' files do NOT exist.
  assert_file_not_exist .ddev/docker-compose.postgres-exporter.yaml
  assert_file_not_exist .ddev/grafana/dashboards/postgres.json

  echo "# Convert project to Postgres" >&3
  ddev delete -Oy
  ddev config --database=postgres:16

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  # Assert 'mysql-exporter' files do NOT exist.
  assert_file_not_exist .ddev/docker-compose.mysql-exporter.yaml
  assert_file_not_exist .ddev/grafana/dashboards/mysql.json

  # Assert 'postgres-exporter' files exist.
  assert_file_exists .ddev/docker-compose.postgres-exporter.yaml
  assert_file_exists .ddev/grafana/dashboards/postgres.json
}

@test "Node metrics are exposed" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  export TARGET_METRIC='node_network_up'

  # Check it exposes endpoint with statistics
  run ddev exec curl -vs node-exporter:9100/metrics
  assert_output --partial "HELP ${TARGET_METRIC}"

  # Prometheus receives metrics
  run curl -sf "https://${PROJNAME}.ddev.site:9090/api/v1/metadata"
  assert_output --partial "${TARGET_METRIC}"
}

@test "Node-exporter port is configurable" {
  set -eu -o pipefail

  export NODE_EXPORTER_HTTP_PORT=9001

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  ddev dotenv set .ddev/.env --node-exporter-http-port="${NODE_EXPORTER_HTTP_PORT}"
  run ddev restart -y
  assert_success

  # Check it exposes endpoint with statistics
  run ddev exec curl -vs "node-exporter:${NODE_EXPORTER_HTTP_PORT}/metrics"
  assert_output --partial 'HELP node_network_up Value is 1'
}

@test "Grafana Loki workflow is configured" {
  set -eu -o pipefail

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  export TARGET_METRIC='loki_build_info'

  # Check it exposes endpoint with statistics
  run ddev exec curl -vs grafana-loki:3100/metrics
  assert_output --partial "HELP ${TARGET_METRIC}"

  # Prometheus receives metrics
  run curl -sf "https://${PROJNAME}.ddev.site:9090/api/v1/metadata"
  assert_output --partial "${TARGET_METRIC}"

  # Query Grafana API for Loki datasource
  run curl -sf "https://${PROJNAME}.ddev.site:3000/api/datasources/uid/loki"
  assert_output --partial '"name":"Loki"'
  assert_output --partial '"url":"http://grafana-loki:3100"'
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success

  run ddev restart -y
  assert_success

  health_checks
}
