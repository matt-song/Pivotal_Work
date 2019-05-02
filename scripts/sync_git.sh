echo "Sync to aio2"
rsync -av --exclude=".git*" ~/Pivotal_Work/ gpadmin@aio2:~/git_repository/
echo "sync to mdw"
rsync -av --exclude=".git*" ~/Pivotal_Work/ gpadmin@mdw:~/git_repository/
