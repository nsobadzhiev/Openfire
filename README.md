Openfire ![alt tag](https://raw.githubusercontent.com/igniterealtime/IgniteRealtime-Website/master/src/main/webapp/images/logo_openfire.gif)
========
[![Openfire CI](https://github.com/igniterealtime/Openfire/workflows/Openfire%20CI/badge.svg?branch=master)](https://github.com/igniterealtime/Openfire/actions?query=workflow%3A%22Openfire+CI%22+branch%3Amaster)  [![Project Stats](https://www.openhub.net/p/Openfire/widgets/project_thin_badge.gif)](https://www.openhub.net/p/Openfire)

About this fork
-----
This fork is an attempt to make Openfire more "cloud-friendly". The idea is to build a container that is fully functioning when it starts while, at the same time, not containing hardcoded credentials.

Currently:
* It receives its database settings via environment variables
  * However, it is still hardcoded to use the MySQL driver
* It receives its database credentials via environment variables
* The server configuration is inherited from the conf directory while building the docker image
  * This includes the certificates in the keystore 
* System properties are read from the database

About
-----
[Openfire] is a real time collaboration (RTC) server licensed under the Open Source Apache License. It uses the only widely adopted open protocol for instant messaging, XMPP (also called Jabber). Openfire is incredibly easy to setup and administer, but offers rock-solid security and performance.

[Openfire] is a XMPP server licensed under the Open Source Apache License.

[Openfire] - an [Ignite Realtime] community project.

Bug Reporting
-------------

Only a few users have access for filling bugs in the tracker. New
users should:

1. Create a Discourse account
2. Login to a Discourse account
3. Click on the New Topic button
4. Choose the [Openfire Dev category](https://discourse.igniterealtime.org/c/openfire/openfire-dev) and provide a detailed description of the bug.

Please search for your issues in the bug tracker before reporting.

Resources
---------

- Documentation: http://www.igniterealtime.org/projects/openfire/documentation.jsp
- Community: https://discourse.igniterealtime.org/c/openfire
- Bug Tracker: http://issues.igniterealtime.org/browse/OF
- Nightly Builds: http://www.igniterealtime.org/downloads/nightly_openfire.jsp

Ignite Realtime
===============

[Ignite Realtime] is an Open Source community composed of end-users and developers around the world who 
are interested in applying innovative, open-standards-based Real Time Collaboration to their businesses and organizations. 
We're aimed at disrupting proprietary, non-open standards-based systems and invite you to participate in what's already one 
of the biggest and most active Open Source communities.

[Openfire]: http://www.igniterealtime.org/projects/openfire/index.jsp
[Ignite Realtime]: http://www.igniterealtime.org
[XMPP (Jabber)]: http://xmpp.org/

Making changes
==============
The project uses [Maven](https://maven.apache.org/) and as such should import straight in to your favourite Java IDE.
The directory structure is fairly straightforward. The main code is contained in:

* `Openfire/xmppserver` - a Maven module representing the core code for Openfire itself

Other folders are:  
* `Openfire/build` - various files use to create installers for different platforms
* `Openfire/distribution` - a Maven module used to bring all the parts together
* `Openfire/documentation` - the documentation hosted at [igniterealtime.org](https://www.igniterealtime.org/projects/openfire/documentation.jsp)
* `Openfire/i18n` - files used for internationalisation of the admin interface
* `Openfire/plugins` - Maven configuration files to allow the various [plugins](https://www.igniterealtime.org/projects/openfire/plugins.jsp) available to be built
* `Openfire/starter` - a small module that allows Openfire to start in a consistent manner on different platforms

#### Docker build
To build the complete project including plugins, run the command (only docker build supported)
and replace the build argument `KEYSTORE_PWD` with the "Openfire keystore pass stage/prod" entry in our password database.
It is important to use the same value since Openfire needs to know that password to access the keystore for secure communication.
This password is persisted in the property store of Openfire which only changes when configured with the admin panel.

The `IMG_TAG` build argument is optional and can be used to clone all plugins for a certain tag.
If this argument has been set then this project should be checked out for the same tag.
```
docker buildx build --ssh default --secret id=aws,src=$HOME/.aws/credentials --build-arg KEYSTORE_PWD=<get-from-pw-db> --build-arg IMG_TAG=<nr_tag> .
```
Executing this command will forward your local SSH key (via SSH agent) and your AWS credentials to the docker build.

##### Prerequisites
To forward your SSH key pair it has to be generated (default file name) and added to your GitHub account.
If no key pair has been created so far run following command:
```
ssh-keygen -t rsa -b 4096 -C "you@example.com"
```

Add some instructions to your ~/.ssh/config file which tells the SSH Agent to automatically load the keys and store the corresponding passphrases.
```
Host *
 UseKeychain yes
 AddKeysToAgent yes
 IdentityFile ~/.ssh/id_rsa
```

Add your private key to the SSH Agent:
```
ssh-add -K ~/.ssh/id_rsa
```

Your AWS credentials have to be configured.

#### Docker local build
To bring up a local MySQL database run:
```
docker-compose -f infra.yml up
```

To build a docker image that contains all plugins and can be locally tested **all plugins and this project have to be
contained in the same folder on your disk.**
Run the following command in the parent directory of this project and replace `<project_folder>` with the name of the folder this project has been cloned to.
```
DOCKER_BUILDKIT=1 docker build -t openfire:latest --secret id=aws,src=$HOME/.aws/credentials -f <poject_folder>/Dockerfile_local --build-arg PROJECT_FOLDER=<project_folder> .
```
This will create a docker image with remote debugging support on port 5005 suspending the JVM until a debugger connected.

If a new plugin needs to be added it has to be added to **Dockerfile_local**.
First the plugin folder needs to be copied to the **packager** image.
```
COPY ./<plugin_name> ./plugins/<plugin_name>
```
This will include it in the Maven build.
The resulting JAR of that plugin has to be copied from the packager image to the final image.
Find this line and replace the comment with the resulting JAR. 
```
COPY --from=packager /usr/src/plugins/openfire-avatar-upload-plugin/target/avatarupload-0.0.1-SNAPSHOT.jar \
    /usr/src/plugins/openfire-voice-plugin/target/voice-0.0.11-SNAPSHOT.jar \
    /usr/src/plugins/openfire-apns/target/openfire-apns.jar \
    # add new plugins here
    /usr/src/plugins/openfire-hazelcast-plugin/target/hazelcast-2.4.2-SNAPSHOT.jar ./plugins/
```

To create the container run this command:
```
docker run --env DB_USER=openfire --env DB_PASS=testpass --env DB_URL=host.docker.internal --env DB_NAME=openfire --env AWS_REGION=eu-central-1 -p 5005:5005 -p 3478:3478 -p 3479:3479 -p 5222:5222 -p 5223:5223 -p 5229:5229 -p 5275:5276 -p 5276:5276 -p 5262:5262 -p 5263:5263 -p 5701:5701 -p 7070:7070 -p 7443:7443 -p 7777:7777 -p 9090:9090 -p 9091:9091 --name openfire openfire:latest
```
The JVM will suspend until a remote debugger has connected.
Then just connect with a remote debugger of your choice to localhost:5005.

Testing your changes
--------------------

#### IntelliJ IDEA:

1. Run -> Edit Configurations... -> Add Application
2. fill in following values
    1. Name: Openfire
    2. Use classpath of module: starter
    3. Main class: org.jivesoftware.openfire.starter.ServerStarter
    4. VM options (adapt accordingly):
        ````
        -DopenfireHome="-absolute path to your project folder-\distribution\target\distribution-base" 
        -Xverify:none
        -server
        -Dlog4j.configurationFile="-absolute path to your project folder-\distribution\target\distribution-base\lib\log4j2.xml"
        -Dopenfire.lib.dir="-absolute path to your project folder-\distribution\target\distribution-base\lib"
        -Dfile.encoding=UTF-8
       ````
   5. Working directory: -absolute path to your project folder-
3. apply

You need to execute `mvnw verify` before you can launch openfire.

##### Docker container
1. Run -> Edit Configurations... -> Add Remote
2. fill in following values
    1. Host: Openfire
    2. Port: 5005
3. apply

In order to test plugins it is necessary to add them in IntelliJ via *File -> New -> Module from Existing Sources...*
If this is done it is possible to set breakpoints. 

#### Other IDE's:

Although your IDE will happily compile the project, unfortunately it's not possible to run Openfire from within the 
IDE - it must be done at the command line. After building the project using Maven, simply run the shell script or 
batch file to start Openfire;
```
./distribution/target/distribution-base/bin/openfire.sh
```
or
```
.\distribution\target\distribution-base\bin\openfire.bat
```

Adding `-debug` as the first parameter to the script will start the server in debug mode, and your IDE should be able
to attach a remote debugger if necessary.
