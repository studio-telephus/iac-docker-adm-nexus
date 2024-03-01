#!/usr/bin/env bash
: "${SERVER_KEYSTORE_STOREPASS?}"

echo "Import custom cacerts to JRE"
keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/jre/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias iamcarsa \
        -file /usr/share/ca-certificates/self-signed/iamcarsa.crt
keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/jre/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias telephuscarsa \
        -file /usr/share/ca-certificates/self-signed/telephuscarsa.crt

echo "Test keytool against keystore."
keytool -list \
 -rfc -keystore /opt/nexus/etc/ssl/keystore.jks \
 -storepass ${SERVER_KEYSTORE_STOREPASS}

echo "Edit Nexus default properties."
cat << EOF > /opt/sonatype/nexus/etc/nexus-default.properties
# Jetty section
application-port-ssl=443
application-host=0.0.0.0
nexus-args=\${jetty.etc}/jetty.xml,\${jetty.etc}/jetty-https.xml,\${jetty.etc}/jetty-requestlog.xml
nexus-context-path=/${NEXUS_CONTEXT}
ssl.etc=\${karaf.data}/etc/ssl

# Nexus section
nexus-edition=nexus-pro-edition
nexus-features=\
 nexus-pro-feature

nexus.hazelcast.discovery.isEnabled=true
EOF

echo "Edit Jetty config."
cat << EOF > /opt/sonatype/nexus/etc/jetty/jetty-https.xml
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

echo "You should now be able to access Nexus."
