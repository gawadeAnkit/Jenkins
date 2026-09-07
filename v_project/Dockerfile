# ==============================================================================
# Dockerfile: VProfile Java 17 / Spring 6 Web Application
# Runtime: Apache Tomcat 10 on Eclipse Temurin JDK 17
# Architecture: Amazon ECR & Amazon ECS (Fargate)
# Author: Ankit Gawade
# ==============================================================================

FROM tomcat:10.1-jdk17-temurin

LABEL maintainer="Ankit Gawade <gawadeankit@github.com>"
LABEL project="VProfile Cloud Native Container"
LABEL description="Spring 6 multi-tier web application running on Apache Tomcat 10 container"

# Set environment variables
ENV APP_PORT=8080
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"

# Remove default Tomcat boilerplate apps to optimize memory & security
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy packaged WAR artifact built by Jenkins Maven stage into Tomcat root context
COPY target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war

# Expose HTTP port for ECS Task Definition
EXPOSE 8080

# Health check probe for ECS container health monitoring
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Start Tomcat service
CMD ["catalina.sh", "run"]
