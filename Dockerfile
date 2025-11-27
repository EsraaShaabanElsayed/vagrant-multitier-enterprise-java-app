# Multi-stage Dockerfile
# Build stage
FROM maven:3.8.8-openjdk-11 AS build
WORKDIR /app

# Copy pom and source to build the WAR
COPY pom.xml ./
COPY src ./src

# Build the project (skip tests to speed up image builds by default)
RUN mvn -B -DskipTests package

# Run stage: use official Tomcat and deploy the generated WAR as ROOT
FROM tomcat:9-jdk11-openjdk

# Remove default webapps to keep image clean
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy built WAR from the build stage into Tomcat's webapps as ROOT.war
COPY --from=build /app/target/*.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh", "run"]
