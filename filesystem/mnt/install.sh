#!/usr/bin/env bash
: "${RANDOM_STRING?}"
: "${SERVER_KEYSTORE_STOREPASS?}"

##
echo "Install the base tools"

apt-get update
apt-get install -y \
 curl vim wget htop unzip gnupg2 netcat-traditional \
 bash-completion software-properties-common

## Run pre-install scripts
sh /mnt/setup-ca.sh


##
echo "Install JDK"

## Retrieve the latest Linux Corretto .tgz package by using a Permanent URL
wget https://corretto.aws/downloads/latest/amazon-corretto-8-x64-linux-jdk.tar.gz

mkdir -p /usr/lib/jvm/jdk-8
tar -xvf amazon-corretto-*.tar.gz -C /usr/lib/jvm/jdk-8 --strip-components 1
/usr/lib/jvm/jdk-8/bin/java -version

update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-8/bin/java" 0
update-alternatives --install "/usr/bin/javac" "javac" "/usr/lib/jvm/jdk-8/bin/javac" 0
update-alternatives --install "/usr/bin/keytool" "keytool" "/usr/lib/jvm/jdk-8/bin/keytool" 0

update-alternatives --set java /usr/lib/jvm/jdk-8/bin/java
update-alternatives --set javac /usr/lib/jvm/jdk-8/bin/javac
update-alternatives --set keytool /usr/lib/jvm/jdk-8/bin/keytool

echo 'JAVA_HOME="/usr/lib/jvm/jdk-8"' >> /etc/environment
echo "Verify Java version"
java -version

keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/jdk-8/jre/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias iamcarsa \
        -file /usr/share/ca-certificates/self-signed/iamcarsa.crt
keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/jdk-8/jre/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias telephuscarsa \
        -file /usr/share/ca-certificates/self-signed/telephuscarsa.crt

## Nexus
echo "Create Dedicated Nexus System Account."
useradd -M -d /opt/nexus -s /bin/bash -r nexus

echo "Allow the nexus user to run all commands with sudo without password."
apt-get install sudo -y
echo "nexus   ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/nexus

echo "Download the current stable release version of Nexus."
wget https://download.sonatype.com/nexus/3/nexus-3.63.0-01-unix.tar.gz

echo "Extract to the nexus user home directory."
tar xzvf nexus-*.tar.gz -C /opt/nexus --strip-components=1

echo "Test keytool against keystore."
keytool -list \
 -rfc -keystore /opt/nexus/etc/ssl/keystore.jks \
 -storepass ${SERVER_KEYSTORE_STOREPASS}

## Configuration

mkdir /opt/sonatype-work
chown -R nexus: /opt/sonatype-work

cat << EOF > /opt/nexus/bin/nexus.vmoptions
-Xms2048m
-Xmx2048m
-XX:MaxDirectMemorySize=2048m
-XX:+UnlockDiagnosticVMOptions
-XX:+LogVMOutput
-XX:LogFile=../sonatype-work/nexus3/log/jvm.log
-XX:-OmitStackTraceInFastThrow
-Djava.net.preferIPv4Stack=true
-Dkaraf.home=.
-Dkaraf.base=.
-Dkaraf.etc=etc/karaf
-Djava.util.logging.config.file=etc/karaf/java.util.logging.properties
-Dkaraf.data=../sonatype-work/nexus3
-Dkaraf.log=../sonatype-work/nexus3/log
-Djava.io.tmpdir=../sonatype-work/nexus3/tmp
-Dkaraf.startLocalConsole=false
-Djdk.tls.ephemeralDHKeySize=2048
-Djava.endorsed.dirs=lib/endorsed
EOF

### To run Nexus in standalone mode, ensure that Nexus is run as nexus user.
cat << EOF > /opt/nexus/bin/nexus.rc
run_as_user="nexus"
EOF

echo "Edit Nexus properties with the following changes."
cat << EOF > /opt/nexus/etc/nexus-default.properties
# Jetty section
application-port-ssl=443
application-host=0.0.0.0
nexus-args=\${jetty.etc}/jetty.xml,\${jetty.etc}/jetty-https.xml,\${jetty.etc}/jetty-requestlog.xml
nexus-context-path=/nexus
ssl.etc=\${karaf.data}/etc/ssl

# Nexus section
nexus-edition=nexus-pro-edition
nexus-features=\
 nexus-pro-feature

nexus.hazelcast.discovery.isEnabled=true
EOF

echo "Edit Jetty config."
cat << EOF > /opt/nexus/etc/jetty/jetty-https.xml
<?xml version="1.0"?>
<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN" "http://www.eclipse.org/jetty/configure_9_0.dtd">
<Configure id="Server" class="org.eclipse.jetty.server.Server">
  <Ref refid="httpConfig">
    <Set name="secureScheme">https</Set>
    <Set name="securePort"><Property name="application-port-ssl" /></Set>
  </Ref>

  <New id="httpsConfig" class="org.eclipse.jetty.server.HttpConfiguration">
    <Arg><Ref refid="httpConfig"/></Arg>
    <Call name="addCustomizer">
      <Arg>
        <New id="secureRequestCustomizer" class="org.eclipse.jetty.server.SecureRequestCustomizer">
          <!-- 7776000 seconds = 90 days -->
          <Set name="stsMaxAge"><Property name="jetty.https.stsMaxAge" default="7776000"/></Set>
          <Set name="stsIncludeSubDomains"><Property name="jetty.https.stsIncludeSubDomains" default="false"/></Set>
          <Set name="sniHostCheck"><Property name="jetty.https.sniHostCheck" default="false"/></Set>
        </New>
      </Arg>
    </Call>
  </New>

  <New id="sslContextFactory" class="org.eclipse.jetty.util.ssl.SslContextFactory$Server">
    <Set name="CertAlias">1</Set>
    <Set name="KeyStorePath">/opt/nexus/etc/ssl/keystore.jks</Set>
    <Set name="KeyStorePassword">${SERVER_KEYSTORE_STOREPASS}</Set>
    <Set name="KeyManagerPassword">${SERVER_KEYSTORE_STOREPASS}</Set>
    <Set name="EndpointIdentificationAlgorithm"></Set>
    <Set name="NeedClientAuth"><Property name="jetty.ssl.needClientAuth" default="false"/></Set>
    <Set name="WantClientAuth"><Property name="jetty.ssl.wantClientAuth" default="false"/></Set>
    <Set name="IncludeProtocols">
      <Array type="java.lang.String">
        <Item>TLSv1.2</Item>
      </Array>
    </Set>
  </New>

  <Call name="addConnector">
    <Arg>
      <New id="httpsConnector" class="org.eclipse.jetty.server.ServerConnector">
        <Arg name="server"><Ref refid="Server" /></Arg>
        <Arg name="acceptors" type="int"><Property name="jetty.https.acceptors" default="-1"/></Arg>
        <Arg name="selectors" type="int"><Property name="jetty.https.selectors" default="-1"/></Arg>
        <Arg name="factories">
          <Array type="org.eclipse.jetty.server.ConnectionFactory">
            <Item>
              <New class="org.sonatype.nexus.bootstrap.jetty.InstrumentedConnectionFactory">
                <Arg>
                  <New class="org.eclipse.jetty.server.SslConnectionFactory">
                    <Arg name="next">http/1.1</Arg>
                    <Arg name="sslContextFactory"><Ref refid="sslContextFactory"/></Arg>
                  </New>
                </Arg>
              </New>
            </Item>
            <Item>
              <New class="org.eclipse.jetty.server.HttpConnectionFactory">
                <Arg name="config"><Ref refid="httpsConfig" /></Arg>
              </New>
            </Item>
          </Array>
        </Arg>

        <Set name="host"><Property name="application-host" /></Set>
        <Set name="port"><Property name="application-port-ssl" /></Set>
        <Set name="idleTimeout"><Property name="jetty.https.timeout" default="30000"/></Set>
        <Set name="acceptorPriorityDelta"><Property name="jetty.https.acceptorPriorityDelta" default="0"/></Set>
        <Set name="acceptQueueSize"><Property name="jetty.https.acceptQueueSize" default="0"/></Set>
      </New>
    </Arg>
  </Call>
</Configure>
EOF

echo "Set ownership of the nexus directory."
chown -R nexus: /opt/nexus

echo "Create a systemd service unit for it as shown below."
cat > /etc/systemd/system/nexus.service << 'EOL'
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOL


echo "Reload the systemd manager configuration."
systemctl daemon-reload

# Ports below 1024 are called Privileged Ports and in Linux (and most UNIX flavors and UNIX-like systems), they are not allowed to be opened by any non-root user. This is a security feature originally implemented as a way to prevent a malicious user from setting up a malicious service on a well-known service port.
# Setting this up means that any user can open privileged ports using Java
setcap cap_net_bind_service+ep /usr/lib/jvm/jdk-8/bin/java

echo "Start and enable Nexus service to run on system reboot"
systemctl enable --now nexus.service

echo "Check the service status."
systemctl status nexus

## cleanup
rm -f amazon-corretto-*.tar.gz

echo "You should now be able to access Nexus."
