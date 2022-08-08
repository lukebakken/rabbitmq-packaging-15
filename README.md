* Build image:

```
git clone https://github.com/lukebakken/rabbitmq-packaging-15.git
cd rabbitmq-packaging-15
docker build --no-cache --pull --tag rabbitmq-packaging-15:latest .
```

* Run container:

```
docker run --interactive --tty --name rabbitmq-packaging-15 rabbitmq-packaging-15:latest /bin/bash
```

* Build windows installer:

```
cd /root

git clone https://github.com/rabbitmq/rabbitmq-packaging.git
git remote add gh-12 https://github.com/inikulshin/rabbitmq-packaging-12.git
git fetch --all

# Note: this is necessary to be able to apply changes from your repo
git reset --hard d70542d1580f2cb84f243ee61e05142325d1ead5

git checkout -b rabbitmq-packaging-12
git merge gh-12/master

cd /root

git clone https://github.com/rabbitmq/rabbitmq-server.git
cd rabbitmq-server
make RABBITMQ_PACKAGING_REPO="/root/rabbitmq-packaging" package-windows
```
