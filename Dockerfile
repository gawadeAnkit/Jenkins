# ==============================================================================
# Dockerfile: VProfile Enterprise Cloud-Native Container (Java 17 / Spring 6)
# Target Architecture: Amazon ECR & Amazon ECS (AWS Fargate)
# Author: Ankit Gawade
# Standards: CIS Docker Benchmark Hardened (Non-Root Execution, Pre-built WAR)
# ==============================================================================

FROM tomcat:10.1-jre17-temurin

# OpenContainer Standard Labels
LABEL org.opencontainers.image.title="VProfile Web Application" \
      org.opencontainers.image.description="Spring 6 multi-tier enterprise web application" \
      org.opencontainers.image.authors="Ankit Gawade <gawadeankit@github.com>" \
      org.opencontainers.image.source="https://github.com/gawadeAnkit/Jenkins" \
      org.opencontainers.image.vendor="Ankit Infotech"

# Environment configuration
ENV APP_PORT=8080 \
    CATALINA_HOME="/usr/local/tomcat" \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -Djava.security.egd=file:/dev/./urandom"

# 1. Clean boilerplate Tomcat default applications (prevents directory traversal & memory leak)
RUN rm -rf ${CATALINA_HOME}/webapps/*

# 2. Security Hardening: Create non-privileged service user and group
RUN groupadd -r tomcat -g 1001 && \
    useradd -u 1001 -r -g tomcat -m -d ${CATALINA_HOME} -s /sbin/nologin tomcat && \
    chown -R tomcat:tomcat ${CATALINA_HOME}/logs ${CATALINA_HOME}/work ${CATALINA_HOME}/temp

# 3. Copy application WAR artifact built by Jenkins Maven stage directly into Tomcat with ownership
COPY --chown=tomcat:tomcat target/vprofile-v2.war ${CATALINA_HOME}/webapps/ROOT.war

# 4. Switch to non-root user (CIS Benchmark Requirement)
USER tomcat

# 5. Expose HTTP traffic port
EXPOSE 8080

# 6. Container Health Check Probe for ECS Task Monitoring
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# 7. Service execution entrypoint
CMD ["catalina.sh", "run"]

