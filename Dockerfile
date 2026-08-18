# ── Stage 1: Build ──
FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /app

# Cache Maven dependencies
COPY .mvn/ .mvn/
COPY mvnw mvnw.cmd pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Build the application
COPY src/ src/
RUN ./mvnw clean package -DskipTests -B

# ── Stage 2: Runtime ──
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Create a non-root user
RUN addgroup -S broker && adduser -S broker -G broker

COPY --from=build /app/target/*.jar app.jar

# Create data directory
RUN mkdir -p /data && chown broker:broker /data

USER broker

EXPOSE 8082

ENTRYPOINT ["java", "-jar", "app.jar"]
