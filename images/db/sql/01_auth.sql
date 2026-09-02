CREATE ROLE authenticator LOGIN NOINHERIT NOCREATEDB NOCREATEROLE NOSUPERUSER;
CREATE ROLE web_anon NOLOGIN;
CREATE ROLE webuser NOLOGIN;

grant usage on schema public to postgres, web_anon;

grant all privileges on all tables in schema public to postgres, web_anon;
grant all privileges on all functions in schema public to postgres, web_anon;
grant all privileges on all sequences in schema public to postgres, web_anon;

alter default privileges in schema public grant all on tables to postgres, web_anon;
alter default privileges in schema public grant all on functions to postgres, web_anon;
alter default privileges in schema public grant all on sequences to postgres, web_anon;