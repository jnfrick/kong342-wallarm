set -ex

docker build --pull --progress=plain \
 --tag jnfrick/kong342-wallarm:latest .
docker push jnfrick/kong342-wallarm:latest
