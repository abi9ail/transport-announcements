#!/bin/bash
docker compose down
docker build --pull ./images/db -t postgres --progress=plain --secret id=api_key,src=secrets/api_key.txt
docker build --pull ./images/asterisk -t asterisk --progress=plain
docker volume prune -f
docker compose up