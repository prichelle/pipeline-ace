FROM cp.icr.io/cp/appc/ace-server-prod@sha256:8c7a80be06567e1e535913ba4ea160000b586b1d3ff632cdad92d7aa1ee23bf6
COPY bars /home/aceuser/bars
USER 0
RUN bash -c "cd /home/aceuser \ 
 && export LICENSE=accept \ 
 && mqsibar -a bars/Integration.bar -w /home/aceuser/ace-server \ 
 && chmod -R 777 /home/aceuser/ace-server/run" 
USER aceuser