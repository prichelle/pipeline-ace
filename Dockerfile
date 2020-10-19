FROM ibmcom/ace-server:latest
COPY source/PingService /home/aceuser/PingService
RUN export LICENSE="accept" \
    && source /opt/ibm/ace-11/server/bin/mqsiprofile \
    && mkdir /home/aceuser/bars
    && mqsipackagebar -a bars/PingService.bar -k PingService \
    && ace_compile_bars.sh \
    && chmod -R 777 /home/aceuser/ace-server/run/PingService