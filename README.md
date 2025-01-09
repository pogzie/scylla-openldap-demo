# scylla-openldap-demo

#build custom scylla image with sasl2-bin vim ldapsearch
$docker compose build

#launches 3 containers scylla, openldap and phpldapadmin 
docker compose up -d

#phpldapadmin is availalbel on localhost 8080
http://localhost:8080

#starts saslauthd process
docker compose exec -it scylla service saslauthd start

#creates roles for users johndoe and anna.meier from ldap
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE ROLE johndoe WITH LOGIN = true; CREATE ROLE 'anna.meier' WITH LOGIN = true;"

#updates scylla.yaml to start using ldap on reboot.
docker compose exec -it scylla cp scylla.yaml.ldap /etc/scylla/scylla.yaml

#restarts scylla server
docker compose exec -it scylla supervisorctl restart scylla

#login to scylla with johndoe from ldap
docker compose exec -it scylla cqlsh -u johndoe -p password123

#login to scylla server if needed
docker compose exec -it scylla bash
