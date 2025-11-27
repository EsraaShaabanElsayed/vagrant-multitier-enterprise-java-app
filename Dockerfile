FROM maven:3.8.6-jdk-8 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean install -DskipTests

FROM tomcat:9.0.75-jre8
WORKDIR /usr/local/tomcat

# Install unzip
RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*

# Remove default webapps
RUN rm -rf webapps/*

# Copy WAR file
COPY --from=build /app/target/*.war webapps/ROOT.war

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["catalina.sh", "run"]
