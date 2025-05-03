#!/bin/bash

docker kill $(docker ps -aqf "name=ps5jsongenerator")
docker rm $(docker ps -aqf "name=ps5jsongenerator")

docker kill $(docker ps -aqf "name=ps5contentloader")
docker rm $(docker ps -aqf "name=ps5contentloader")

docker kill $(docker ps -aqf "name=ps5contentserver")
docker rm $(docker ps -aqf "name=ps5contentserver")