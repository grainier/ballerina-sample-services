# ballerina-sample-services

This repository contains 4 Ballerina services that I used to test Ballerina Observability.
It tests http services, http clients and jdbc clients.

All four service can be run using the following commands.
Since all four services can not start up the prometheus endpoint on port 9797, the default port has been overridden.

```
ballerina run --observe store.bal
ballerina run --observe -e b7a.observability.metrics.prometheus.port=9798 order.bal
ballerina run --observe -e b7a.observability.metrics.prometheus.port=9799 product.bal
ballerina run --observe -e b7a.observability.metrics.prometheus.port=9800 inventory.bal
```

Following is a sample `prometheus.yml` file that can be used to configure prometheus to scrape data from all 4 endpoints.
(172.17.0.1 is the docker ip and works for Ubuntu. MAC users might have to use 0.0.0.0 instead).

```
global:
  scrape_interval:     15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['172.17.0.1:9797', '172.17.0.1:9798', '172.17.0.1:9799', '172.17.0.1:9800']
```

Sample cURL command 
`http://localhost:9090/StoreService/processOrder?orderId=2`
