# syntax=docker/dockerfile:1
FROM debian AS pbx-db
EXPOSE 5432

# Add volumes for the database and downloaded API data
ENV PGDATA=/var/local/pgsql/data
ENV GTFSDATA=/usr/local/src/sydneytrains
VOLUME ["$PGDATA", "$GTFSDATA"]

# Set up filesystem permissions
RUN useradd -m -s /bin/bash postgres
RUN mkdir -p /var/local/pgsql/data 
RUN chown postgres:postgres -R /var/local/pgsql
RUN mkdir -p /usr/local/src/sydneytrains
RUN chown postgres:postgres -R /usr/local/src
RUN chmod -R 0755 /usr/local/src

# Install prerequisites
RUN apt-get update && apt-get install -y unzip curl postgresql postgresql-common python3-full python3-pip sudo wget &&\
    service postgresql stop

# Create a Python virtual environment
FROM pbx-db AS pbx-db-python
RUN mkdir /usr/local/envs &&\
    python3 -m venv /usr/local/envs/venv &&\
    . /usr/local/envs/venv/bin/activate &&\
    /usr/local/envs/venv/bin/python3 -m pip install xlsx2csv

# Initialise Database
FROM pbx-db-python AS pbx-db-deploy
USER postgres
RUN /usr/lib/postgresql/17/bin/pg_ctl initdb -D /var/local/pgsql/data -o "--encoding=UTF-8 --auth-local=trust --auth=trust"
RUN echo "host all all 0.0.0.0/0 md5" >> /var/local/pgsql/data/pg_hba.conf

WORKDIR /usr/local/src
HEALTHCHECK --interval=15m --retries=1 --timeout=10m CMD bash -c "/usr/local/src/update-gtfs.sh | stdbuf -oL cut -d '' -f1 | xargs echo $(date '+%Y-%m-%d %H:%M:%S') | tee /proc/1/fd/1" 

COPY --chown=postgres:postgres --chmod=0755 sql sql
COPY --chown=postgres:postgres --chmod=0755 update-gtfs.sh .
RUN --mount=type=secret,id=api_key,target=/run/secrets/api_key,uid=1000 \
    /usr/lib/postgresql/17/bin/pg_ctl start -D /var/local/pgsql/data -l /var/local/pgsql/data/logfile.log -o "-h '*'" &&\
    psql -c "ALTER USER postgres WITH PASSWORD 'postgres';" &&\
    cat sql/*.sql | psql
ENTRYPOINT /usr/lib/postgresql/17/bin/postgres -D /var/local/pgsql/data -h '*'