FROM python:3.10-slim

WORKDIR /app

RUN pip install --no-cache-dir -U pip setuptools wheel

COPY . .

RUN pip install --no-cache-dir -e .

ENV PYTHONUNBUFFERED=.

COPY ./target/pushfight-message-passer_linux_amd64 pushfight-message-passer_linux_amd64 
COPY ./target/index.html index.html
COPY ./target/elm.min.js elm.min.js

ENTRYPOINT [ "/app/pushfight-message-passer_linux_amd64" ]
