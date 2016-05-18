# Docker Android CI Image 

This Docker image includes JDK, Android SDK and Jenkins.

# Build

sudo docker build -t android-ci .

# Usage

sudo docker run -d -p 80:8080 -p 50000:50000 -v /home/ubuntu:/var/jenkins_home android-ci

Note: This will store the jenkins data in `/home/ubuntu` on the host.