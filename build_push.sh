set -ex

docker build --pull --progress=plain \
 --tag jnfrick/kong342-wallarm:4.10.6 .
docker push jnfrick/kong342-wallarm:4.10.6
