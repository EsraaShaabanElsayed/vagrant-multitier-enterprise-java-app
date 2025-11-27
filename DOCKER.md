# Docker / Docker Compose

This repository now includes a `Dockerfile` and `docker-compose.yml` to build and run the application inside containers.

Quick start (build and run with Compose):

```bash
docker-compose up --build
```

This will:
- Build the webapp image using Maven to produce the WAR, then start Tomcat with the WAR deployed as `ROOT`.
- Start a MariaDB container and initialize it with `src/main/resources/db_backup.sql`.
 - Start RabbitMQ (with management UI) and an Nginx reverse-proxy that forwards HTTP traffic to the Tomcat app.

Default ports and credentials used by `docker-compose.yml`:
- App: `http://localhost:8080/`
- MariaDB: username `vprofile`, password `secret`, database `vprofile` (root password `rootpassword`)
 - RabbitMQ: AMQP `5672`, management UI `http://localhost:15672` (user `user` / pass `pass`)
 - Nginx (reverse proxy): `http://localhost/` forwards to the app on port `8080`

If you prefer to build the image manually and run it without Compose:

```bash
# Build image
docker build -t vagrant-java-app .

# Run container (links the app to a DB externally as needed)
docker run -p 8080:8080 vagrant-java-app
```

Notes and next steps:
- If your application reads DB connection settings from `application.properties`, you can override them via environment variables or by mounting a custom `application.properties` into the image at runtime.
- If your project uses a different DB init SQL path, update `docker-compose.yml` accordingly.
- To enable tests during image build, remove `-DskipTests` from the Maven command in the `Dockerfile`.
- The `docker-compose.yml` places all services on a user network called `appnet`; the app uses service hostnames (`db`, `rabbitmq`) to reach them.
- If you want secrets in files or environment files instead of plaintext in `docker-compose.yml`, move credentials into a `.env` or use Docker secrets.

Accessing service UIs:
- App: `http://localhost:8080/` (or via Nginx at `http://localhost/`)
- RabbitMQ management: `http://localhost:15672` (user: `user`, pass: `pass`)
- MariaDB does not expose a UI by default; connect using a DB client to `localhost:3306` with credentials above.

