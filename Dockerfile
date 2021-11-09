FROM icr.io/appc-dev/ace-server@sha256:c58fc5a0975314e6a8e72f2780163af38465e6123e3902c118d8e24e798b7b01
COPY bars /home/aceuser/bars
USER 0
RUN bash -c "cd /home/aceuser \ 
 && export LICENSE=accept \ 
 && chmod 777 bars/Integration.bar" 
RUN ls -la bars
RUN bash -c "mqsibar -a bars/Integration.bar -w /home/aceuser/ace-server \ 
 && chmod -R 777 /home/aceuser/ace-server/run \ 
 && ls -la /home/aceuser/ace-server/run"
RUN ls -la /home/aceuser/ace-server/run
USER aceuser