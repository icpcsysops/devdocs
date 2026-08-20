# ===== ICPC SPECIFIC REQUIREMENTS =====
# Fully qualify the base image: we build with podman, which has no implicit
# Docker Hub default and would otherwise prompt for a registry.
FROM docker.io/ruby:4.0.5
# ===== END ICPC SPECIFIC REQUIREMENTS =====
ENV LANG=C.UTF-8
ENV ENABLE_SERVICE_WORKER=true

WORKDIR /devdocs

RUN apt-get update && \
    apt-get -y install git nodejs libcurl4 && \
    gem install bundler && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock Rakefile /devdocs/

RUN bundle config set path.system true && \
    bundle install && \
    rm -rf ~/.gem /root/.bundle/cache /usr/local/bundle/cache

COPY . /devdocs

RUN thor docs:download --all && \
    thor assets:compile && \
    rm -rf /tmp

EXPOSE 9292
CMD rackup -o 0.0.0.0
