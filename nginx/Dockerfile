FROM nginx:alpine

# Install openssl for certificate generation and wget for health checks
RUN apk add --no-cache openssl wget

# Set up workdir
WORKDIR /

# Standard nginx entrypoint is used, but we will wrap it or replace it if needed.
# For now, we rely on the entrypoint.sh script provided in the project.
