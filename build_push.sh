set -ex

docker build --pull --progress=plain \
 --tag jnfrick/kong342-wallarm:4.10.3 .
docker push jnfrick/kong342-wallarm:4.10.3
