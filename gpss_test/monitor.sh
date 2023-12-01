while :; 
do
    psql -c 'select * from gpkafka_gpss_from_kafka_59adb30a1fe73465dd526311e07b547b order by 1 desc limit 5'
    sleep 2
done
