# docker-observium
Dockerfile, etc. to build a dockerized version of observium for arm32v7

* Configure:
Edit Dockerfile and change usernames, passwords, hosts, language and timezone to suit you.  Make the corresponding changes to docker-compose.yml.  In addition make a unique tag for your observium container if you intend to push it to dockerhub.  It's not necessary to push it but I build the container on an x86-64 system and pushing it and pulling it is the easist way to get it from the build machine to the raspberry pi.  If you have a pi4 it might be faster to build on the pi, but its not on a pi3

* Build:
docker build -t <your tag> .

* Run:
docker-compose up -d 

