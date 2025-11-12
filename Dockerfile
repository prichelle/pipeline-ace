# Use tagged version for better maintainability
# To update: icr.io/appc-dev/ace-server:12.0.2.0-r1 or latest stable version
FROM icr.io/appc-dev/ace-server@sha256:c58fc5a0975314e6a8e72f2780163af38465e6123e3902c118d8e24e798b7b01

# Copy BAR files to integration server initial config
COPY bars /home/aceuser/initial-config/bars

# Set proper permissions (use 755 instead of 777 for better security)
USER 0
RUN chmod -R 755 /home/aceuser/initial-config/bars && \
    chown -R aceuser:aceuser /home/aceuser/initial-config/bars

# Accept license and switch to non-root user
ENV LICENSE=accept
USER aceuser