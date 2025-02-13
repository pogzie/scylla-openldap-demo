# Scylla OpenLDAP Demo

Configure: 
- `ldap/bootstrap.ldif` - LDAP objects you can edit and would be boostrapped on start
- `scylla/scylla.ldap` - Edit if you have changes to `role_manager` related values
- `scylla/saslauthd.conf` - Edit if you want to change LDAP related connection/filter rules
- `compose.yml` - It might be wise to "simulate" your production setup with the corresponding values for the LDAP server.
- `Dockerfile` - Modify for specific version tests `FROM scylladb/scylla-enterprise:2024.1.14`

Note:
- If you want to test your `ldap_url_template` for correctness a simple `curl` command replacing the user value should work: `curl -u "cn=admin,dc=example,dc=org" "ldap://openldap:389/ou=IT,dc=example,dc=org?cn?sub?(uniqueMember=uid=anna.meier,ou=IT,dc=example,dc=org)"`
- Volumes are created, take note when cleaning up or fresh installing.

### Clone repo, build and start
```
git clone https://github.com/pogzie/scylla-openldap-demo
cd scylla-openldap-demo
docker compose build
docker compose up -d
```

### Sanity check for Scylla and start `saslauthd`
```
docker compose exec -it scylla nodetool status
docker compose exec -it scylla service saslauthd start
```

### About roles with users login 
There is no need to create users when authorization is set. 

<del>`docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE ROLE johndoe WITH LOGIN = true; CREATE ROLE 'anna.meier' WITH LOGIN = true;"`</del>


### Create roles read only and read write
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE ROLE read_only; CREATE ROLE read_write;"
```

### Grant permissions 
There is no need to grant permissions as the authorization associates via the LDAP object

<del>`#docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "GRANT 'read_only' TO 'anna.meier'; GRANT 'read_write' TO 'johndoe';"`</del>


### Create permissions for all keyspaces for read_write and read_only roles
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "GRANT SELECT ON ALL KEYSPACES TO read_only;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "GRANT SELECT ON ALL KEYSPACES TO read_write;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "GRANT MODIFY ON ALL KEYSPACES TO read_write;"
```

### Double check created permissions
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "LIST ALL PERMISSIONS OF read_only;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "LIST ALL PERMISSIONS OF read_write;"
```

### Double check current roles
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "SELECT * FROM system_auth.roles;"
```

### Sanity check LDAP bootstrap

```
docker compose exec -it openldap /usr/bin/ldapsearch -D "cn=admin,dc=example,dc=org" -w "adminpassword" -x  -h ldap://openldap:389 -p 389  -b "dc=example,dc=org" -s sub "(objectClass=*)"
```

### Enable Scylla LDAP
```
docker compose exec -it scylla cp scylla.ldap /etc/scylla/scylla.yaml
docker compose exec -it scylla supervisorctl restart scylla
sleep 10
docker compose exec -it scylla nodetool status
```

### Sanity check after enabling Scylla LDAP
Note: You can follow the `scylla` container logs and see the messages when doing the queries above
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "SELECT * FROM system_auth.roles;"
docker compose exec -it scylla cqlsh -u johndoe -p password123 -e "SELECT * FROM system_auth.roles;"
docker compose exec -it scylla cqlsh -u anna.meier -p password456 -e "SELECT * FROM system_auth.roles;"
```
This next command is expected to fail as `peter.schmidt` is NOT a member of the IT ou
```
# Expected to fail (not in any roles per role manager)
docker compose exec -it scylla cqlsh -u peter.schmidt  -p password789 -e "SELECT * FROM system_auth.roles;"
```

### Create keyspace and table with roles
Create using the `cassandra` user
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE KEYSPACE my_keyspace WITH replication = {'class': 'NetworkTopologyStrategy','replication_factor': 1};"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE TABLE my_keyspace.my_table (id text, name text, age int, PRIMARY KEY (id));"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "INSERT INTO my_keyspace.my_table (id, name, age) VALUES ('6ab09bec-e68e-48d9-a5f8-97e6fb4c9b47', 'Tom Bombadil',999);"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "SELECT * from my_keyspace.my_table;"
```

### Test with the read_write role
```
docker compose exec -it scylla cqlsh -u johndoe -p password123 -e "INSERT INTO my_keyspace.my_table (id, name, age) VALUES ('63b09bec-e68e-23d2-a5f8-97e6fb4c9c37', 'Frodo Baggins',50);"
docker compose exec -it scylla cqlsh -u johndoe -p password123 -e "SELECT * from my_keyspace.my_table;"
```

### Test with the read_only role
```
docker compose exec -it scylla cqlsh -u anna.meier -p password456 -e "INSERT INTO my_keyspace.my_table (id, name, age) VALUES ('62cf6c03-6548-4b37-8d7d-e8a92d36129c', 'Samwise Gamgee',39);"
docker compose exec -it scylla cqlsh -u anna.meier -p password456 -e "SELECT * from my_keyspace.my_table;"
```

### Additional CQLSH Tests
Some commands will not work as intended. See note in https://enterprise.docs.scylladb.com/stable/operating-scylla/security/ldap-authorization.html#introduction 

### You can NOT drop roles (users and roles)
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "DROP ROLE read_only;"
```

### You CAN create users with LOGIN = true but login is still LDAP dependent. You can NOT create a user with a password
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE ROLE johnsmith WITH LOGIN = true;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "CREATE ROLE scyllauserwithpw WITH PASSWORD = 'helloworld' AND LOGIN = true;"
```

### You can NOT alter roles and change passwords (LDAP should do this)
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "ALTER ROLE johndoe WITH PASSWORD = 'helloworld';"
```

### You CAN alter roles and grant SUPERUSER
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "ALTER ROLE johndoe WITH SUPERUSER = true;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "SELECT * FROM system_auth.roles;"
```

### You CAN alter keyspaces
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "ALTER KEYSPACE my_keyspace WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': '3'}  AND durable_writes = true;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "DESCRIBE KEYSPACE my_keyspace;"
```

### GRANT permissions
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "GRANT MODIFY ON ALL KEYSPACES TO read_only;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "GRANT SELECT ON ALL KEYSPACES TO read_only;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "LIST ALL PERMISSIONS OF read_only;"
```

### Test GRANT
From the command above, `read_only` is granted `MODIFY` on `ALL KEYSPACES`. So `anna.meier` should now be able to write into `my_keyspace.my_table`.
```
docker compose exec -it scylla cqlsh -u anna.meier -p password456 -e "INSERT INTO my_keyspace.my_table (id, name, age) VALUES ('62cf6c03-6548-4b37-8d7d-e8a92d36129c', 'Samwise Gamgee',27);"
docker compose exec -it scylla cqlsh -u anna.meier -p password456 -e "SELECT * from my_keyspace.my_table;"
```

### REVOKE permissions
We will now revoke the privilages given to `read_only` where `anna.meier` is a member of. 
```
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "REVOKE MODIFY ON ALL KEYSPACES FROM read_only;"
docker compose exec -it scylla cqlsh -u cassandra -p cassandra -e "LIST ALL PERMISSIONS OF read_only;"
```

### Test REVOKE
```
docker compose exec -it scylla cqlsh -u anna.meier -p password456 -e "INSERT INTO my_keyspace.my_table (id, name, age) VALUES ('cac06674-f1cb-41db-b9fc-4aab2f69a3d2', 'Meriadoc Brandybuck',36);"
```

### Cleanup
```
docker compose down -v
```

### Other notes
- phpLDAPAdmin is installed, login as `cn=admin,dc=example,dc=org` with `adminpassword`
- A group `scylla_group` is bootstrapped in case further testing with groups is needed. Uncomment `ldap_group_dn` and `ldap_group_attr` in `scylla/saslauthd.conf` then run `service saslauthd restart` in the `scylla` container to apply. Only `johndoe` is listed as a member of that group
