## Hetzner Failover changer ##

#### Motivation ####
This script was written to simplify failover subnet switching between
production and mirror hosts at my company 

#### Usage ####

./hetzner-failover -c $config.yml -t $target-server-ip -i $failover-ip

#### Configuration ####

config.yml should contain two keys
* username
* password

example config looks like:

```
username: 'my_username'
password: 'passw0rd'
```


#### About me #####
I'm yet another sysadmin who likes ruby...
