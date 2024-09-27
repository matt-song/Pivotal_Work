for host in `gcloud compute instances list | grep "^matt-"  | grep RUNNING | awk '{print $1}'`; do 
    gcloud compute instances stop --zone=asia-east2-a $host ;
done
