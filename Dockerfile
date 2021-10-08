FROM image-registry.openshift-image-registry.svc:5000/ace/ace-minimal:12.0.1.0-alpine
COPY bars /home/aceuser/bars
USER 0
RUN bash -c "cd /home/aceuser \ 
 && export LICENSE=accept \ 
 && . /opt/ibm/ace-12/server/bin/mqsiprofile \ 
 && mqsibar -a bars/Integration.bar -w /home/aceuser/ace-server \ 
 && find /home/aceuser/ace-server/run -type d -exec chmod -R 777 {} \;" 
USER aceuser
