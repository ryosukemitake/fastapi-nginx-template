# fastapi nginx template

it's fast api and nginx template but currently it does not work as i expected.
when you curl localhost, it responses 502 bad gateway instaed of hellow world which is defined in main.py ... 

docker logs web shows `
connect() failed (111: Connection refused) while connecting to upstream, client: 172.27.0.1, server: ` in nginx container.



## file tree

```
.
├── Dockerfile
├── README.md
├── docker-compose.yml
├── main.py
├── nginx
│   ├── Dockerfile
│   └── nginx.conf
└── requirements.txt
```

## build and start

1. `docker-compose up -d --build`

2. `docker logs ps -a`

```
CONTAINER ID   IMAGE                         COMMAND                  CREATED         STATUS         PORTS                                       NAMES
cb79d9efaf75   fast-api-nginx-template_web   "/docker-entrypoint.…"   4 minutes ago   Up 4 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp           web
6b049c395508   fast-api-nginx-template_api   "uvicorn main:app --…"   4 minutes ago   Up 4 minutes   0.0.0.0:8000->8000/tcp, :::8000->8000/tcp   api
```

3. `curl localhost`

```
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.21.1</center>
</body>
</html>
```

4. `docker logs web`
```
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2021/08/28 13:58:37 [error] 31#31: *8 connect() failed (111: Connection refused) while connecting to upstream, client: 172.27.0.1, server: 127.0.0.1, request: "GET / HTTP/1.1", upstream: "http://172.27.0.3:8000/", host: "localhost"
172.27.0.1 - - [28/Aug/2021:13:58:37 +0000] "GET / HTTP/1.1" 502 157 "-" "curl/7.64.1"
```

5. `docker logs api`
```
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```


## docker-compose

docker-compose
```
version: "3.9"
services:
    web:
        container_name: web
        build: nginx
        ports:
          - 80:80
        depends_on:
          - api
        networks:
          - local-net
    api:
        container_name: api
        build: .
        ports:
          - 8000:8000
        networks:
          - local-net
        expose:
          - 8000
networks:
  local-net:
    driver: bridge
```

## web


nginx/Dockerfile
```
FROM nginx
RUN apt-get update 
COPY nginx.conf /etc/nginx/nginx.conf
```

nginx/nginx.conf
```
worker_processes 1;

events {
  worker_connections 1024; 
  accept_mutex off; 
  use epoll;
}

http {
    include mime.types;
    upstream app_serve {
        server web:8000;
    }
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    server {
        listen 80 ipv6only=on;
        server_name 127.0.0.1;   
        location / {
            proxy_pass http://app_serve; 
            proxy_set_header Host               $host;
            proxy_set_header X-Real-IP          $remote_addr;
            proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  $scheme;
        }
    }
}
```

## api

Dockerfile
```
ARG BASE_IMAGE=python:3.8-buster                                                                                
FROM $BASE_IMAGE                                                                                                     

RUN apt-get -y update && \                                                                                           
    apt-get install -y --no-install-recommends \                                                                     
    build-essential \                                                                                                
    openssl libssl-dev \                                                                                             
    && apt-get clean \                                                                                               
    && rm -rf /var/lib/apt/lists/*                                                                                   

ARG USER_NAME=app
ARG USER_UID=1000
ARG PASSWD=password

RUN useradd -m -s /bin/bash -u $USER_UID $USER_NAME && \
    gpasswd -a $USER_NAME sudo && \
    echo "${USER_NAME}:${PASSWD}" | chpasswd && \
    echo "${USER_NAME} ALL=(ALL) ALL" >> /etc/sudoers

COPY ./ /app
RUN chown -R ${USER_NAME}:${USER_NAME} /app

USER $USER_NAME
WORKDIR /app
ENV PATH $PATH:/home/${USER_NAME}/.local/bin

RUN pip3 install --user --upgrade pip 
RUN pip3 install --user -r requirements.txt
RUN rm -rf ~/.cache/pip/* 

EXPOSE 8000

# Execute
CMD ["uvicorn", "main:app", "--host", "127.0.0.1" ,"--port" ,"8000"]
```

main.py
```
from typing import Optional
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def load_root():
    return {"Hello": "World"}

@app.get("/items/{item_id}")
def load_item(item_id: int, q: Optional[str] = None):
    return {"item_id": item_id, "q": q}

```