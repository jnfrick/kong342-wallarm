set -ex

docker build --pull --progress=plain \
 --tag jfrick/kong342-wallarm:latest .
# docker push jfrick/kong342-wallarm:latest
