FROM amazon/aws-cli as aws
# required build arguments
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_REGION

# download push notification credentials from S3, the servers private key and the signed certificate
RUN aws configure set default.region $AWS_REGION \
    && aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID \
    && aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY \
    && aws s3 cp s3://com.feinfone.build/apns/apns_key.p8 /usr/local/openfire/authKey.p8 \
    && aws s3 cp s3://com.feinfone.build/cert/feinfone.key /usr/local/openfire/feinfone.key \
    && aws s3 cp s3://com.feinfone.build/cert/feinfone_ca.crt /usr/local/openfire/feinfone_ca.crt

# Maven target to build the Openfire artifact
FROM maven:3.6.2-jdk-11 as packager

# required build arguments
ARG KEYSTORE_PWD

ARG AWS_REGION
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

WORKDIR /usr/src

COPY ./pom.xml .
COPY ./i18n/pom.xml ./i18n/
COPY ./xmppserver/pom.xml ./xmppserver/
COPY ./starter/pom.xml ./starter/
COPY ./starter/libs/* ./starter/libs/
COPY ./plugins/pom.xml ./plugins/
COPY ./plugins/openfire-plugin-assembly-descriptor/pom.xml ./plugins/openfire-plugin-assembly-descriptor/
COPY ./distribution/pom.xml ./distribution/

WORKDIR ca
# copy the certificate from aws build stage and create a keystore with it
COPY --from=aws /usr/local/openfire/feinfone.key \
     /usr/local/openfire/feinfone_ca.crt \
     ./

RUN openssl pkcs12 -export -in feinfone_ca.crt -inkey feinfone.key -out keystore.p12 -name "feinfone.com" -password pass:$KEYSTORE_PWD \
    && keytool -importkeystore -destkeystore keystore -deststorepass $KEYSTORE_PWD -srckeystore keystore.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PWD

WORKDIR /usr/src

# set AWS credentials to let Maven have acces to it
RUN apt-get update && apt-get -y install awscli \
    && aws configure set default.region $AWS_REGION \
    && aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID \
    && aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

# build with Maven

RUN mvn dependency:go-offline
COPY . .
RUN mvn -Denv=release package

# final image target
FROM openjdk:11-jre-slim as build
COPY --from=packager /usr/src/distribution/target/distribution-base /usr/local/openfire
COPY --from=packager /usr/src/build/docker/entrypoint.sh /sbin/entrypoint.sh
WORKDIR /usr/local/openfire

COPY build/docker/inject_db_settings.sh \
     build/docker/inject_hazelcast_settings.sh \
     build/docker/template_openfire.xml \
     build/docker/template_hazelcast.xml \
     build/docker/template_security.xml \
     ./

# copy push notification credentials
COPY --from=aws /usr/local/openfire/authKey.p8 .

# copy keystore with self signed certificate
COPY --from=packager /usr/src/ca/keystore ./resources/security/

ENV OPENFIRE_USER=openfire \
    OPENFIRE_DIR=/usr/local/openfire \
    OPENFIRE_DATA_DIR=/var/lib/openfire \
    OPENFIRE_LOG_DIR=/var/log/openfire

RUN apt-get update -qq \
    && apt-get install -yqq sudo \
    && adduser --disabled-password --quiet --system --home $OPENFIRE_DATA_DIR --gecos "Openfire XMPP server" --group openfire \
    && chmod 755 /sbin/entrypoint.sh \
    && chown -R openfire:openfire ${OPENFIRE_DIR} \
    && mv ${OPENFIRE_DIR}/conf ${OPENFIRE_DIR}/conf_org \
    && mv ${OPENFIRE_DIR}/plugins ${OPENFIRE_DIR}/plugins_org \
    && mv ${OPENFIRE_DIR}/resources/security ${OPENFIRE_DIR}/resources/security_org \
    && rm -rf /var/lib/apt/lists/*

LABEL maintainer="florian.kinder@fankserver.com"

EXPOSE 3478/tcp 3479/tcp 5222/tcp 5223/tcp 5229/tcp 5275/tcp 5276/tcp 5262/tcp 5263/tcp 5701/tcp 7070/tcp 7443/tcp 7777/tcp 9090/tcp 9091/tcp
VOLUME ["${OPENFIRE_DATA_DIR}"]
CMD ["/sbin/entrypoint.sh"]
