#### Status
[ ] Step#1: get the list of url
[ ] Step#2: parse the url 
[ ] Step#3: store the content to DB 
[ ] Step#4: web page

## Step#1 get the latest version
- latest 4: https://gpdb.docs.pivotal.io/43latest/main/index.html
- latest 5: https://gpdb.docs.pivotal.io/5latest/main/index.html
- latest 6: https://gpdb.docs.pivotal.io/6latest/main/index.html

## Step#2 go through all the doc. save the resolved issue section to local as csv

```
curl https://gpdb.docs.pivotal.io/6latest/main/index.html
Redirecting to <a href="/6-10/main/index.html">/6-10/main/index.html</a>
get top version 6.10
then for ver in range 6.1 ~ 6.10. do: get the content of url
```

## Step#3 import the csv to DB 
`release, jira, component, description...`
