[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/tyler36/ddev-site-metrics/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/tyler36/ddev-site-metrics/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/tyler36/ddev-site-metrics)](https://github.com/tyler36/ddev-site-metrics/commits)
[![release](https://img.shields.io/github/v/release/tyler36/ddev-site-metrics)](https://github.com/tyler36/ddev-site-metrics/releases/latest)

# DDEV Site Metrics <!-- omit in toc -->

- [Overview](#overview)
- [Installation](#installation)
- [Tools](#tools)
  - [Grafana](#grafana)
    - [Configure Datasources](#configure-datasources)
    - [Configure Dashboards](#configure-dashboards)
    - [Configure plugins](#configure-plugins)
    - [Grafana Alloy](#grafana-alloy)
      - [Usage](#usage)
  - [Grafana Loki](#grafana-loki)
    - [Grafana Tempo](#grafana-tempo)
  - [Prometheus](#prometheus)
    - [Customize Prometheus](#customize-prometheus)
    - [Addon: Nginx Exporter](#addon-nginx-exporter)
    - [Addon: MySql Exporter](#addon-mysql-exporter)
    - [Addon: Postgres Exporter](#addon-postgres-exporter)
    - [Addon: node-exporter](#addon-node-exporter)
- [Credits](#credits)

## Overview

This addon contains tools for using [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-collector) with a DDEV project.

It contains the following packages:

- [Prometheus](https://prometheus.io/docs/introduction/overview/): an open-source systems monitoring and alerting toolkit.
- [Grafana](https://grafana.com/docs/grafana/latest/): Query, visualize, alert on, and explore your metrics, logs, and traces.

## Installation

To install this add-on, run:

```shell
ddev add-on get tyler36/ddev-site-metrics
ddev restart
```

After installation, make sure to commit the .ddev directory to version control.

## Tools

### Grafana

[Grafana](https://grafana.com/docs/grafana/latest/) is a tool to "Query, visualize, alert on, and explore your metrics, logs, and traces wherever they are stored.".

#### Configure Datasources

This addon pre-configures Prometheus as a datasource.

- To include customize, or include additional datasources, update `.ddev/grafana/datasources/grafana-datasources.yml`.

See [Grafana data sources](https://grafana.com/docs/grafana/latest/datasources/#grafana-data-sources).

#### Configure Dashboards

This add-on pre-configures `.ddev/grafana/dashboards` as the provisioned dashboard folder.
See [Dashboards](https://grafana.com/docs/grafana/latest/dashboards/).
See [Dashboard JSON model](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/).

#### Configure plugins

To install a plugin, create or update `.ddev/docker-compose.grafana_custom.yaml`.
Replace `<plugin-id>` with the plugin ID.

```yaml
services:
  grafana:
    environment:
      - GF_PLUGINS_PREINSTALL=<plugin-id>
```

To find the plugin ID:

- visit [All plugins for Grafana](https://grafana.com/grafana/plugins/all-plugins/).
- search for the desired plugin.
- click the "Installation" tab.
- Look at the "Install the Panel" code. In the below example, `grafana-clock-panel` is the plugin ID.

    ```shell
    grafana-cli plugins install grafana-clock-panel
    ```

#### Grafana Alloy

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) can collect, process, and export telemetry signals to scale and future-proof your observability approach.

This addon configures Grafana Alloy to collect and process:

- Docker logs (`alloy/docker.alloy`),
- Alloy logs (`alloy/alloy-logs.alloy`)
- Enable live debugging of Alloy pipelines, where supported
- Adds a pipeline to a DDEV-supported Grafana Loki process

To configure Alloy, add/update files in `.ddev/alloy`. By default, all files in this directory are loaded and processed.

##### Usage

Grafana Alloy runs within the process on its default port of `12345`.

- To open the Grafana Alloy dashboard, run the following command:

```shell
ddev alloy
```

- To reload Alloy configuration, run the following command:

```shell
ddev alloy -r
```

### Grafana Loki

[Grafana Loki](https://grafana.com/docs/loki/latest/) is a set of open source components that can be composed into a fully featured logging stack.

Grafana Loki listens on its default port of `3100`.
To view processed logs, visit `Drilldown | Logs` in the Grafana dashboard.

```shell
ddev :3000/a/grafana-lokiexplore-app/explore
```

#### Grafana Tempo

[Grafana Tempo](https://grafana.com/docs/tempo/latest/) is an open-source, easy-to-use, and high-scale distributed tracing backend.

In this add-on, Grafana Alloy forwards open telemetry data it receives to Grafana Tempo for processing ([./alloy/otelcol.alloy](./alloy/otelcol.alloy)). Grafana Tempo datasource is pre-configured in Grafana allowing a centralized location for interacting with traces.

- To configure Grafana Tempo, update `.ddev/tempo/tempo-config.yaml` and restart DDEV.
- To forward Grafana Tempo traces to Grafana, update `.ddev/.env.tempo`

```conf
OTEL_SERVICE_NAME="tempo"
OTEL_EXPORTER_OTLP_ENDPOINT="http://alloy:4318"
```

### Prometheus

[Prometheus](https://prometheus.io/docs/introduction/overview/) is an open-source systems monitoring and alerting toolkit originally built at [SoundCloud](https://soundcloud.com/).

Prometheus collects and stores its metrics as time series data, i.e. metrics information is stored with the timestamp at which it was recorded, alongside optional key-value pairs called labels.

To open Prometheus: `ddev prometheus` or `ddev launch :9090` (assuming the default port).

#### Customize Prometheus

Prometheus is configured via `./.ddev/prometheus/prometheus.yml`. This addon provides an example, but need to customize it for your use-case.

To customize, take ownership by removing `#ddev-generated` and making the changes as required.
The example polls `/metrics` in the WEB container every 5 seconds.

```yml
global:
  scrape_interval: 5s  # How often Prometheus scrapes data

scrape_configs:
  - job_name: 'web'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['web'] # Change to your app's hostname and port. Here, we use DDEV web container.
```

- To customize the default port, update `.ddev/.env`

```config
PROMETHEUS_HTTPS_PORT=9090
```

#### Addon: Nginx Exporter

The Nginx Exporter uses [NGINX Prometheus exporter](https://hub.docker.com/r/nginx/nginx-prometheus-exporter) to monitor NGINX or NGINX Plus using Prometheus.

This addon pre-configures the Nginx Prometheus exporter for a DDEV environment
In additional, an example dashboard is available in Grafana.

Key files include:

- `docker-compose.nginx-exporter.yaml`: loads NGINX Prometheus exporter image
- `.ddev/nginx_full/stub_status.conf`: Exposes stub statistics from Nginx

#### Addon: MySql Exporter

[MySql Exporter](https://hub.docker.com/r/prom/mysqld-exporter) exports MySQL server metrics into Prometheus.
The metrics can be used in Grafana:

- monitor the health of the container
- detect slow queries
- detect issue during stress tests

This addon includes an example dashboard inspired by [MySQL Overview](https://grafana.com/grafana/dashboards/7362-mysql-overview/).

To use, ensure the `.ddev/prometheus/prometheus.yml` file scrapes the endpoint:

```yml
scrape_configs:
  ...
  - job_name: mysql # To get metrics about the mysql exporter's targets
    metrics_path: /probe
    params:
      # Not required. Will match value to child in config file. Default value is `client`.
      auth_module: [client.servers]
    static_configs:
      - targets:
        # All mysql hostnames or unix sockets to monitor.
        - db:3306
        # Uncomment to target unix sockets.
        - unix:///run/mysqld/mysqld.sock
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        # The mysqld_exporter host:port
        replacement: mysqld-exporter:9104
```

#### Addon: Postgres Exporter

[Postgres-exporter](https://github.com/prometheus-community/postgres_exporter) exposes PostgreSQL server metrics to Prometheus.

To use, ensure the `.ddev/prometheus/prometheus.yml` file scrapes the endpoint:

```yml
scrape_configs:
  ...
  # Get exposed Postgres metrics
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
```

Key files include:

- `docker-compose.postgres-exporter.yaml`: loads Postgres-exporter image

Exposed metrics use the following prefixes: `pg` and `postgres`.

#### Addon: node-exporter

[Node Exporter](https://github.com/prometheus/node_exporter) is a Prometheus exporter for hardware and OS metrics exposed by *NIX kernels, written in Go with pluggable metric collectors.

To use, ensure the `.ddev/prometheus/prometheus.yml` file scrapes the endpoint:

```yml
scrape_configs:
  ...
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

By default, node-exporter is accessible via `node-exporter:9100` inside the docker container.
To change the port,

- update `NODE_EXPORTER_HTTP_PORT="9100"` in `.ddev/.env`.
- update the scrape config in `.ddev/prometheus/prometheus.yml`.
- restart DDEV to apply the changes.

This addon includes an example node dashboard based on [Node Exporter Full (v40)](https://grafana.com/grafana/dashboards/1860-node-exporter-full/).

## Credits

PRs for install steps for specific frameworks are welcome.

**Contributed and maintained by [`@tyler36`](https://github.com/tyler36)**
