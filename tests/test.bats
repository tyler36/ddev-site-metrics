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
  prometheus_health_check
  grafana_health_check
}

prometheus_health_check() {
  run curl -sf "https://${PROJNAME}.ddev.site:9090/query"
  assert_output --partial "Prometheus Time Series Collection and Processing Server"
}

grafana_health_check() {
  run curl -sf "https://${PROJNAME}.ddev.site:3000"
  assert_output --partial "<title>Grafana</title>"
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

@test "Prometheus port is configurable" {
  set -eu -o pipefail

  export PROMETHEUS_HTTPS_PORT=9043

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  ddev dotenv set .ddev/.env --prometheus-https-port="${PROMETHEUS_HTTPS_PORT}"
  run ddev restart -y
  assert_success

  run curl -sf "https://${PROJNAME}.ddev.site:${PROMETHEUS_HTTPS_PORT}/query"
  assert_output --partial "Prometheus Time Series Collection and Processing Server"
}

@test "Grafana port is configurable" {
  set -eu -o pipefail

  export GRAFANA_HTTPS_PORT=3043

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  ddev dotenv set .ddev/.env --grafana-https-port="${GRAFANA_HTTPS_PORT}"
  run ddev restart -y
  assert_success

  run curl -sf "https://${PROJNAME}.ddev.site:${GRAFANA_HTTPS_PORT}"
  assert_output --partial "Grafana"
}

@test "Grafana is pre-configured with Prometheus datasource" {
  set -eu -o pipefail

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  # Grafana uses the HTTP endpoint, so check that the datasources contains the correct URL.
  run ddev exec -s grafana cat /etc/grafana/provisioning/datasources/ddev-prometheus.yml
  assert_output --partial 'url: http://prometheus:9090'
}

@test "Grafana is pre-configured with DDEV MySQL datasource" {
  set -eu -o pipefail

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  # Check MySQL settings
  run ddev exec -s grafana cat /etc/grafana/provisioning/datasources/ddev-mysql.yml
  assert_output --partial 'url: db:3306'
  assert_output --partial 'database: db'
  assert_output --partial 'user: db'
  assert_output --partial 'password: db'
}

@test "Grafana is pre-configured with DDEV Postgres datasource" {
  set -eu -o pipefail

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  # Check Postgres settings
  run ddev exec -s grafana cat /etc/grafana/provisioning/datasources/ddev-postgres.yml
  assert_output --partial 'url: db:5432'
  assert_output --partial 'database: db'
  assert_output --partial 'user: db'
  assert_output --partial 'password: db'
}

@test "Nginx-prometheus-exporter exposes statistics" {
  set -eu -o pipefail

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Check it exposes scraping URI
  run ddev exec curl -vs http://web:8080/stub_status
  assert_output --partial 'server accepts handled request'

  # Check it exposes endpoint with statistics
  run ddev exec curl -vs nginx-prometheus-exporter:9113/metrics
  assert_output --partial 'HELP nginx_connections_accepted Accepted client connections'
}

@test "MySQL-exporter exposes statistics" {
  set -eu -o pipefail

  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success

  run ddev restart -y
  assert_success

  # Check it exposes endpoint with statistics
  run ddev exec curl -s mysqld-exporter:9104/metrics
  assert_output --partial 'HELP mysql_up Whether the MySQL server is up.'
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
