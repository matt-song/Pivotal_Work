gpsscli stop gpss_test --gpss-port 5019
gpsscli submit --name gpss_test --gpss-port 5019 ~/gpss/memory_test2.yaml
psql -c ' truncate gpss_from_kafka ;'
psql -c 'vacuum full gpss_from_kafka;'
psql -c 'truncate gpkafka_gpss_from_kafka_59adb30a1fe73465dd526311e07b547b;'
gpsscli start gpss_test --gpss-port 5019
psql gpperfmon -c 'truncate gpmetrics.gpcc_queries_history'
