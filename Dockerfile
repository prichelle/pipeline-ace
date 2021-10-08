FROM image-registry.openshift-image-registry.svc:5000/ace/ace-minimal:12.0.1.0-alpine
COPY bars /home/aceuser/bars
USER aceuser
ENV LICENSE=accept
RUN mqsibar -a bars/Integration.bar -w /home/aceuser/ace-server \
    && find /home/aceuser/ace-server/run -type d -exec chmod -R 777 {} \;
