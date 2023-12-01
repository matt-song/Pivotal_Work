psql gpperfmon -c "select ssid,tstart,memory,cpu_master,cpu_segs,peak_memory,query_text  from gpmetrics.gpcc_queries_history where username = 'etl_user' and query_text ~ 'INSERT' order by peak_memory desc limit 15;"
psql gpperfmon -c "select cast(sum(memory)/1024 as int)||' MB' as memory  from gpmetrics.gpcc_queries_history where username = 'etl_user' ;"
psql -c "select max(endtime) - min(starttime) as duration  from gpkafka_gpss_from_kafka_59adb30a1fe73465dd526311e07b547b ;"
psql -c "select distinct(version) from gpkafka_gpss_from_kafka_59adb30a1fe73465dd526311e07b547b ;"
