File=$1
AllItem=$2

if [ "x$File" = 'x' ] || [ "x$AllItem" = 'x' ] 
then
    echo "Usage: $0 [gpcheckcat output] [Item to check]"
    exit 1
fi

for Item in $AllItem
do
    echo -e "Checking the Error in [$Item]...\n"
    count=`cat $File  | grep -E " $Item has [0-9]+ issue\(s\)$" | awk '{print $(NF-1)}'` 
    grep -A $(($count+1)) -E " $Item has [0-9]+ issue\(s\)$" $File

    echo -e "\nGenerating SQL for error in [$Item]...\n"
    header=`grep -A $(($count+1)) -E " $Item has [0-9]+ issue\(s\)$" $File | head -2  | grep "|" | awk '{print $1}'`
    
    for i in `grep -A $(($count+1)) -E " $Item has [0-9]+ issue\(s\)$" $File | grep "|" | awk '{print $1}' | grep -v oid | sort -u`; 
    do 
        echo "SELECT oid,* from $Item where $header = $i;"; 
    done

    echo ""

    for i in `grep -A $(($count+1)) -E " $Item has [0-9]+ issue\(s\)$" $File | grep "|" | awk '{print $1}' | grep -v oid | sort -u`; 
    do 
        echo "SELECT gp_segment_id,* from gp_dist_random('$Item') where $header = $i;"; 
    done
done