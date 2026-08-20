# ===== ICPC SPECIFIC REQUIREMENTS =====
# Fully qualify the base image: we build with podman, which has no implicit
# Docker Hub default and would otherwise prompt for a registry.
FROM docker.io/ruby:4.0.5
# ===== END ICPC SPECIFIC REQUIREMENTS =====
ENV LANG=C.UTF-8
ENV ENABLE_SERVICE_WORKER=true
# ===== ICPC SPECIFIC REQUIREMENTS =====
# Serve in production mode: gzip, ETag/Cache-Control, minified digested assets,
# and manifests parsed once at boot instead of on every request. RACK_ENV is set
# before `thor assets:compile` runs so the compiled bundle matches what is served.
# Baked in as the image default so no invocation has to pass it; still
# overridable with --build-arg RACK_ENV=... at build time or -e RACK_ENV=... at
# run time. newrelic_rpm is in the :production bundle group and gets required
# along with it, so keep the agent inert on a network with no egress.
ARG RACK_ENV=production
ENV RACK_ENV=${RACK_ENV}
ENV NEW_RELIC_AGENT_ENABLED=false
# ===== END ICPC SPECIFIC REQUIREMENTS =====

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
