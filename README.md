# Nexus Artifactory

[Main article](https://kifarunix.com/install-nexus-repository-manager-on-debian/)
This tutorial covers the installation of Nexus repository manager on Debian LXD container.
The OSS version of the Nexus repository manager allows you to universally manage binaries and artifacts.

## Proceed with manual install

If the install script was successful, you should be able to access Nexus [here](https://nexus.dev.acme.corp/nexus).

## (Optional) Create a reverse proxy for external access

    <Location /nexus>
        ProxyPass https://nexus.adm.acme.corp:443/nexus
        ProxyPassReverse https://nexus.adm.acme.corp:443/nexus
    </Location>

### Setup Nexus Repository Manager

Open Nexus and click the sign in button at the top right corner. 
The *admin* user password is located on the file, /opt/sonatype-work/nexus3/admin.password

Once you logged in, click next to proceed to setup Nexus.

1. Reset Nexus repository admin password
2. Configure anonymous access. You can choose to disable the anonymous access to secure Nexus repositories by requiring user to authenticate before they can browser through the repositories.
3. Finish the setup

You can go through the settings and make adjustments to suite your needs.

### Helpers

Check the service status;

    systemctl status nexus

It might take sometime for Nexus to start. While starting, tail the logs;

    tail -f /opt/sonatype-work/nexus3/log/nexus.log
    ...
    2021-08-05 08:54:16,455+0000 INFO  [jetty-main-1]  *SYSTEM org.eclipse.jetty.server.handler.ContextHandler - Started o.e.j.w.WebAppContext@407b3d1{Sonatype Nexus,/,file:///opt/nexus/public/,AVAILABLE}
    2021-08-05 08:54:16,541+0000 INFO  [jetty-main-1]  *SYSTEM org.eclipse.jetty.server.AbstractConnector - Started ServerConnector@5380bc30{HTTP/1.1, (http/1.1)}{0.0.0.0:8081}
    2021-08-05 08:54:16,591+0000 INFO  [jetty-main-1]  *SYSTEM org.eclipse.jetty.server.Server - Started @268689ms
    2021-08-05 08:54:16,596+0000 INFO  [jetty-main-1]  *SYSTEM org.sonatype.nexus.bootstrap.jetty.JettyServer -
    -------------------------------------------------    
    Started Sonatype Nexus OSS 3.33.0-01

Nexus listens on TCP port 8081 by default;

    netstat -altnp | grep :443
