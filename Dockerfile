FROM icr.io/appc-dev/ace-server@sha256:3714e2236265a557a78bc743fadd0923e4b78ee6a9f6dc321b6856bf0cd4d5fc
COPY bars /home/aceuser/bars
USER 0
RUN bash -c "cd /home/aceuser \ 
 && export LICENSE=accept \ 
 && mqsibar -a bars/Integration.bar -w /home/aceuser/ace-server \ 
 && chmod -R 777 /home/aceuser/ace-server/run" 
USER aceuser