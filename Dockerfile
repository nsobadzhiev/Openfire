# TODO probably pass build arguments with docker-compose
ARG VERSION_DBACCESS=1.2.2
ARG VERSION_REGISTRATION=1.7.2
ARG VERSION_RESTAPI=1.4.0
ARG VERSION_SUBSCRIPTION=1.4.0

# Maven target to get all dependencies
FROM maven:3.6.2-jdk-11 as packager
WORKDIR /usr/src

COPY pom.xml .
COPY i18n/pom.xml ./i18n/
COPY xmppserver/pom.xml ./xmppserver/
COPY starter/pom.xml ./starter/
COPY ./starter/libs/* ./starter/libs/
COPY plugins/pom.xml ./plugins/
COPY plugins/openfire-plugin-assembly-descriptor/pom.xml ./plugins/openfire-plugin-assembly-descriptor/
COPY distribution/pom.xml ./distribution/

# get all necessary plugins
# official plugins
# DB Access (Official Openfire plugin)
RUN wget https://www.igniterealtime.org/projects/openfire/plugins/${VERSION_DBACCESS}/dbaccess.jar -O ./plugins/dbaccess.jar
# Registration (Official Openfire plugin)
RUN wget https://www.igniterealtime.org/projects/openfire/plugins/${VERSION_REGISTRATION}/registration.jar -O ./plugins/registration.jar
# REST API (Official Openfire plugin)
RUN wget https://www.igniterealtime.org/projects/openfire/plugins/${VERSION_RESTAPI}/restAPI.jar -O ./plugins/restAPI.jar
# Subscription (Official Openfire plugin)
RUN wget https://www.igniterealtime.org/projects/openfire/plugins/${VERSION_SUBSCRIPTION}/subscription.jar -O ./plugins/subscription.jar

# our plugins
# [Avatar upload plugin](https://github.com/voiceup-chat/openfire-avatar-upload-plugin)
RUN git clone git@github.com:voiceup-chat/openfire-avatar-upload-plugin.git
# [Voice Upload](https://github.com/voiceup-chat/openfire-voice-plugin)
RUN git clone git@github.com:voiceup-chat/openfire-voice-plugin.git
# [Feinfone APNS](https://github.com/voiceup-chat/openfire-apns)
RUN git clone git@github.com:voiceup-chat/openfire-apns.git
# [Hazelcast plugin](https://github.com/nsobadzhiev/openfire-hazelcast-plugin)
RUN git clone git@github.com:nsobadzhiev/openfire-hazelcast-plugin.git

COPY ./openfire-avatar-upload-plugin/pom.xml ./openfire-avatar-upload-plugin/
COPY ./openfire-voice-plugin/pom.xml ./openfire-voice-plugin/
COPY ../openfire-apns/pom.xml ./openfire-apns/
COPY ../openfire-hazelcast-plugin/pom.xml ./openfire-hazelcast-plugin/

RUN mvn dependency:go-offline

COPY starter .
RUN mvn package

ENV OPENFIRE_USER=openfire \
    OPENFIRE_DIR=/usr/local/openfire \
    OPENFIRE_DATA_DIR=/var/lib/openfire \
    OPENFIRE_LOG_DIR=/var/log/openfire \

# build target
FROM openjdk:11-jre-slim as build
COPY --from=packager /usr/src/distribution/target/distribution-base ${OPENFIRE_DIR}
COPY --from=packager /usr/src/build/docker/entrypoint.sh /sbin/entrypoint.sh

COPY build/docker/inject_db_settings.sh ${OPENFIRE_DIR}/inject_db_settings.sh
COPY build/docker/inject_hazelcast_settings.sh ${OPENFIRE_DIR}/inject_hazelcast_settings.sh
COPY build/docker/template_openfire.xml ${OPENFIRE_DIR}/template_openfire.xml
COPY build/docker/template_hazelcast.xml ${OPENFIRE_DIR}/template_hazelcast.xml
COPY build/docker/template_security.xml ${OPENFIRE_DIR}/template_security.xml
#COPY build/docker/apns_key.p8 ${OPENFIRE_DIR}/authKey.p8

# (move all plugin JARs to the plugin folder)
WORKDIR ${OPENFIRE_DIR}/plugins
COPY --from=packager /usr/src/openfire-avatar-upload-plugin/target/openfire-avatar-upload-plugin.jar .
COPY --from=packager /usr/src/openfire-voice-plugin/target/openfire-voice-plugin.jar .
COPY --from=packager /usr/src/openfire-apns/target/openfire-apns.jar .
COPY --from=packager /usr/src/openfire-hazelcast-plugin/target/openfire-hazelcast-plugin.jar .

# fill config

# rewire openfire

# initialize data directory

# initialize log directory

WORKDIR ${OPENFIRE_DIR}

RUN apt-get update -qq \
    && apt-get install -yqq sudo \
    && adduser --disabled-password --quiet --system --home $OPENFIRE_DATA_DIR --gecos "Openfire XMPP server" --group ${OPENFIRE_USER} \
    && chmod 755 /sbin/entrypoint.sh \
    && chown -R ${OPENFIRE_USER}:${OPENFIRE_USER} ${OPENFIRE_DIR} \
    && mv ${OPENFIRE_DIR}/conf ${OPENFIRE_DIR}/conf_org \
    && mv ${OPENFIRE_DIR}/plugins ${OPENFIRE_DIR}/plugins_org \
    && mv ${OPENFIRE_DIR}/resources/security ${OPENFIRE_DIR}/resources/security_org \
    && rm -rf /var/lib/apt/lists/*

LABEL maintainer="florian.kinder@fankserver.com"

# TODO maybe use docker-compose to set ports, volumes and build arguments
EXPOSE 3478/tcp 3479/tcp 5222/tcp 5223/tcp 5229/tcp 5275/tcp 5276/tcp 5262/tcp 5263/tcp 5701/tcp 7070/tcp 7443/tcp 7777/tcp 9090/tcp 9091/tcp
VOLUME ["${OPENFIRE_DATA_DIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]

# TODO: introduce a release target that uses JRE instread of JDK
