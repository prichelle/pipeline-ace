FROM ibmcom/ace-server:latest
COPY source /home/aceuser/source
RUN export LICENSE="accept" \
    && source /opt/ibm/ace-11/server/bin/mqsiprofile \
    && /opt/ibm/ace-11/server/bin/mqsipackagebar -a bars/PingService.bar -k PingService \
    && ace_compile_bars.sh \
    && chmod -R 777 /home/aceuser/ace-server/run/PingService