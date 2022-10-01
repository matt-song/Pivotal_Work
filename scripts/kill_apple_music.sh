ps -ef | grep 'System/Applications/Music.app/Contents/MacOS/Music' | grep -v grep  | awk '{print $2}' | xargs kill
