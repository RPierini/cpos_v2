# syntax=docker/dockerfile:1

FROM mwalbeck/python-poetry:1.5-3.11

WORKDIR /cpos

VOLUME ["/cpos"]

RUN apt-get update && apt-get install -y default-mysql-server

COPY . /cpos

RUN poetry install

EXPOSE 3306
