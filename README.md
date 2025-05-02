[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/tyler36/ddev-site-metrics/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/tyler36/ddev-site-metrics/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/tyler36/ddev-site-metrics)](https://github.com/tyler36/ddev-site-metrics/commits)
[![release](https://img.shields.io/github/v/release/tyler36/ddev-site-metrics)](https://github.com/tyler36/ddev-site-metrics/releases/latest)

# DDEV Site Metrics <!-- omit in toc -->

- [Overview](#overview)
- [Installation](#installation)
- [Tools](#tools)
  - [Prometheus](#prometheus)
    - [Customize Prometheus](#customize-prometheus)
  - [Grafana](#grafana)
    - [Configure Datasources](#configure-datasources)
    - [Configure Dashboards](#configure-dashboards)
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

## Credits

PRs for install steps for specific frameworks are welcome.

**Contributed and maintained by [`@tyler36`](https://github.com/tyler36)**
