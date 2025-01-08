# scylla-openldap-demo

create a custom scylla container with sasl2-bin and vim 

create needed ldap server and viewer
http://localhost:8081

login to scylla container 

docker compose exec -it scylla service saslauthd restart
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE ROLE johndoe WITH LOGIN = true; CREATE ROLE 'anna.meier' WITH LOGIN = true;"
modify ./scylla/scylla.yaml to to enable sasl and ldap
---
#authenticator: PasswordAuthenticator
authenticator: com.scylladb.auth.SaslauthdAuthenticator
saslauthd_socket_path: /var/run/saslauthd/mux
----
docker compose exec -it scylla supervisorctl restart scylla

login to scylla with johndoe from ldap

docker compose exec -it scylla cqlsh -u johndoe -p password123
