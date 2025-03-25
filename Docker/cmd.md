## Docker compose

#### Start Container(s)

`docker compose -f Docker/a1_payasam_launch.yml up -d`

`docker compose -f Docker/a2_sundal_launch.yml up -d`

`docker compose -f Docker/a3_vadai_launch.yml up -d`

#### Stop Container(s)

`docker compose -f Docker/a1_payasam_launch.yml down`

`docker compose -f Docker/a2_sundal_launch.yml down`

`docker compose -f Docker/a3_vadai_launch.yml down`

#### Run unbound

`docker run --name=unbound-rpi --publish=5335:5335/udp --publish=5335:5335/tcp --restart=unless-stopped --detach=true mvance/unbound-rpi:latest`
  
#### Check Running Docker Containers

 `docker ps`
Displays a list of currently running Docker containers.

#### View Docker Logs

`docker logs <container_name_or_id>`
Displays logs for a specific Docker container, useful for debugging container issues.

#### Check Docker Container Health
Check the health status of a running Docker container.
  
*variant - 1*
`docker inspect --format='{{.State.Health.Status}}' <container_name_or_id>`  

*variant - 2*
`docker ps -q | xargs -I {} sh -c 'docker inspect --format="{{.Name}}: {{with .State.Health}}{{.Status}}{{else}}No Health Check{{end}}" {}'`

#### Swap Memory

`cat /proc/sys/vm/swappiness`

`sudo sysctl -p`

`sudo nano /etc/sysctl.conf`
