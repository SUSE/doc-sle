FROM susedoc/ci:openSUSE-42.3

# copy the sources
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY . /usr/src/app
