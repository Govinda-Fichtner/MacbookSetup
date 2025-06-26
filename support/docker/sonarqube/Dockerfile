# Multi-stage build for SonarQube MCP Server
FROM gradle:8.11.1-jdk21 AS builder

WORKDIR /app

# Clone the official SonarQube MCP Server repository
RUN git clone https://github.com/SonarSource/sonarqube-mcp-server.git .

# Build the JAR
RUN ./gradlew clean build -x test

# Get the version from gradle.properties and copy the JAR
RUN APP_VERSION=$(grep "^version=" gradle.properties | cut -d'=' -f2) && \
    echo "Building version: $APP_VERSION" && \
    cp build/libs/sonarqube-mcp-server-${APP_VERSION}.jar /app/sonarqube-mcp-server.jar

# Final stage - use their Dockerfile approach but simplified
FROM eclipse-temurin:21-jre-alpine

RUN apk add --no-cache nodejs=~22 npm

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    mkdir -p /home/appuser/.sonarlint ./storage && \
    chown -R appuser:appgroup /home/appuser ./storage

COPY --from=builder --chown=appuser:appgroup --chmod=755 /app/sonarqube-mcp-server.jar ./sonarqube-mcp-server.jar

USER appuser

ENV STORAGE_PATH=./storage
ENV SONARQUBE_TOKEN=
ENV SONARQUBE_ORG=
ENV SONARQUBE_URL=

ENTRYPOINT ["java", "-jar", "./sonarqube-mcp-server.jar"]
