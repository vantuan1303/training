#!/bin/bash
eval `docker-machine env manager1`

docker service update --network-add user_backend api-gateway_app