
#JDBC Configuration for Database Connection
jdbc.driverClassName=org.mariadb.jdbc.Driver
jdbc.url=jdbc:mysql://${db_endpoint}/${db_name}?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull
jdbc.username=${db_username}
jdbc.password=${db_password}

#Memcached Configuration For Active and StandBy Host
#For Active Host
memcached.active.host=${memcached_endpoint}
memcached.active.port=11211

#RabbitMQ Configuration
rabbitmq.address=${rabbitmq_endpoint}
rabbitmq.port=5671
rabbitmq.username=${rabbitmq_username}
rabbitmq.password=${rabbitmq_password}

# Spring Boot Configuration
spring.datasource.url=jdbc:mysql://${db_endpoint}/${db_name}
spring.datasource.username=${db_username}
spring.datasource.password=${db_password}
spring.datasource.driver-class-name=org.mariadb.jdbc.Driver
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MariaDB103Dialect
