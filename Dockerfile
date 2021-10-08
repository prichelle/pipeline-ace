FROM cp.icr.io/cp/appc/ace-server-prod@sha256:eed0750a788047982b3f7ddcf6f6762d46e6c54aca3098dff8ddd25197bcebbc
COPY bars /home/aceuser/bars
USER 0
RUN bash -c "cd /home/aceuser \ 
 && export LICENSE=accept \ 
 && . /opt/ibm/ace-12/server/bin/mqsiprofile \ 
 && mqsibar -a bars/Integration.bar -w /home/aceuser/ace-server \ 
 && chmod -R 777 /home/aceuser/ace-server/run \;" 
USER aceuser