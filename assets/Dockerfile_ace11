FROM ibmcom/ace-server:latest
COPY bars /home/aceuser/bars
RUN export LICENSE="accept" \
    && source /opt/ibm/ace-11/server/bin/mqsiprofile \
    && mqsibar -a bars/Integration.bar -w /home/aceuser/ace-server \
    && find /home/aceuser/ace-server/run -type d -exec chmod -R 777 {} \;
