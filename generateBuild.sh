#!/bin/bash

docker kill $(docker ps -aqf "name=ps5jsongenerator")
docker rm $(docker ps -aqf "name=ps5jsongenerator")

# Build the image (lowercase name)
docker build --no-cache -t ps5jsongenerator .

# Run the container
docker run -d \
  -v /volume1/games/ps4:/volume1/games/ps4 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e OUTPUT_DIR=_ps5ContentLoader \
  -e GAME_DIR=/volume1/games/ps4 \
  -e SERVER_URL=http://192.168.1.190:8084 \
  -e JSON_GAMES=GAMES.json \
  -e JSON_UPDATES=UPDATES.json \
  -e JSON_DLC=DLC.json \
  --name ps5jsongenerator \
  ps5jsongenerator:latest

