# Configuration
<!-- ##ddev-generated -->

This directory is contains Grafana Alloy configuration files.

Grafana Alloy finds `*.alloy` files (ignoring nested directories) and loads them as a single configuration source. However, component names must be unique across all Grafana Alloy configuration files, and configuration blocks must not be repeated.

See [Components](https://grafana.com/docs/alloy/latest/reference/components/).

To send content to DDEV's Loki implementation, forward content to `loki.write.default.receiver`

```yaml
  forward_to = [loki.write.default.receiver]
```

- To disable a configuration, rename the extension to `.example`.
