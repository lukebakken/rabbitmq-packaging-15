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
