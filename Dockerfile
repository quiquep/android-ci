FROM codetroopers/jenkins-slave-jdk8

MAINTAINER Enrique Pennimpede "epennimpede@devspark.com"

ENV PATH $PATH:$ANDROID_HOME/tools
ENV PATH $PATH:$ANDROID_HOME/platform-tools
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --force-yes expect git wget libc6-i386 lib32stdc++6 lib32gcc1 lib32ncurses5 lib32z1 && apt-get clean

# Install Android SDK
RUN cd /opt && wget --output-document=android-sdk.tgz --quiet http://dl.google.com/android/android-sdk_r24.3.4-linux.tgz && tar xzf android-sdk.tgz && rm -f android-sdk.tgz && chown -R jenkins.jenkins android-sdk-linux 

# Setup environment
ENV ANDROID_HOME /opt/android-sdk-linux
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools

# Install sdk elements
COPY tools /opt/tools
ENV PATH ${PATH}:/opt/tools

USER jenkins

RUN ["/opt/tools/android-accept-licenses.sh", "android update sdk --all --no-ui --filter platform-tools,tools,build-tools-23.0.3,android-23,addon-google_apis_x86-google-23,extra-android-support,extra-android-m2repository,extra-google-m2repository,sys-img-armeabi-v7a-android-23"]

RUN which adb
RUN which android

USER root

RUN echo ANDROID_HOME="$ANDROID_HOME" >> /etc/environment

RUN apt-get update && apt-get install -y git curl zip && rm -rf /var/lib/apt/lists/*

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.5}
ARG JENKINS_SHA
ENV JENKINS_SHA ${JENKINS_SHA:-5e669825a955c9091ac8a858f4f6dcae782f3d87}


# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA  /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh