#rsync -av --exclude=".git*" ~/git_repository/ gpadmin@aio:~/git_repository/
echo "Sync to aio2"
rsync -av --exclude=".git*" ~/git_repository/ gpadmin@aio2:~/git_repository/
echo "sync to mdw"
rsync -av --exclude=".git*" ~/git_repository/ gpadmin@mdw:~/git_repository/
