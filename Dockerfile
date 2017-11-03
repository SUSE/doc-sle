FROM opensuse:tumbleweed

# "zypper dup" synchronizes with the current Tumbleweed (even downgrades if needed),
# we need to install curl for downloading/installing the GPG key
# Note: we can keep the metadata cache as this image is only used once at Travis
RUN zypper --non-interactive dup --no-recommends && \
  zypper --non-interactive in --no-recommends curl

# import the Documentation:Tools GPG key
RUN rpm --import https://build.opensuse.org/projects/Documentation:Tools/public_key

RUN zypper ar -f https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Tumbleweed/ Documentation:Tools

# Note: unfortunately this pulls in a *lot* of not needed packages like samba, texlive
# which are not needed for validation, but when we lock them the install command
# below fails in non-interactive mode :-(
# RUN zypper addlock texlive-* samba-* ghostscript cups-libs transfig *-fonts mozilla-*
# saxon6 is required by jing but it's not installed automatically via dependencies
RUN zypper --non-interactive in --no-recommends daps saxon6

# copy the sources
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY . /usr/src/app
