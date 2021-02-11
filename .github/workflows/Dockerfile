FROM openbuildservice/obs-docu
ARG CONTAINER_USERID

# Configure our user id
RUN usermod -u $CONTAINER_USERID frontend

WORKDIR /obs-docu
USER frontend

# Run our command
CMD ["/bin/bash", "-l"]
