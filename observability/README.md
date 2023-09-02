# Observability

## Summary
1. Install node_exporter on all pis
1. install grafana and prometheus on one host: study.local

## Grafana configuration
1. Set username and password to admin / admin on first login : http://study.local:3000
1. Add prometheus datasource http://study.local:3000/connections/datasources :
    1. HTTP > Prometheus server URL: `http://localhost:9090`
    1. Interval behaviour > Scrape interval: `10s`
    1. Performance > Prometheus type: `Prometheus`
1. Add ["Node Exporter Full"](https://grafana.com/grafana/dashboards/1860-node-exporter-full/) dashboard http://study.local:3000/dashboard/import :
    1. Import via grafana.com: 1860

## Files used
The grafana DB is a sqlite file: `sudo sqlite3 /var/lib/grafana/grafana.db`

Prometheus stores data at the path specified by the `--storage.tsdb.path` flag.
