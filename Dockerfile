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