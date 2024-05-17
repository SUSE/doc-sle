FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest

RUN zypper --gpg-auto-import-keys -n ref && zypper -n in sudo system-group-wheel itstool python39

### Gitpod user ###
# '-l': see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN groupadd -g 33333 gitpod && \
    useradd -l -u 33333 -g 33333 -G wheel -md /home/gitpod -s /bin/bash -p gitpod gitpod && \
    # passwordless sudo for users in the 'wheel' group
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/00-wheel-group-nopasswd

ENV HOME=/home/gitpod
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo ". /etc/bash_completion.d/git-prompt.sh" && echo "PS1='\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\$(__git_ps1 \" (%s)\") $ '" ; } >> .bashrc

### Gitpod user (2) ###
USER gitpod
# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Gitpod: success" && \
    # create .bashrc.d folder and source it in the bashrc
    mkdir -p /home/gitpod/.bashrc.d && \
    (echo; echo "for i in \$(ls -A \$HOME/.bashrc.d/); do source \$HOME/.bashrc.d/\$i; done"; echo) >> /home/gitpod/.bashrc

