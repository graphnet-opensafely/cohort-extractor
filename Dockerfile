# syntax=docker/dockerfile:1.2

#################################################
#
# Base cohort-extractor image, with its system dependencies installed.
#
#
# hadolint ignore=DL3007
FROM ghcr.io/opensafely-core/base-action:latest as base-cohortextractor

# we need ca-certificates to validate the microsoft repo
RUN --mount=type=cache,target=/var/cache/apt /root/docker-apt-install.sh ca-certificates

# using apt-helper means we don't need to install curl
RUN /usr/lib/apt/apt-helper download-file https://packages.microsoft.com/keys/microsoft.asc /etc/apt/trusted.gpg.d/microsoft.asc && \
    /usr/lib/apt/apt-helper download-file https://packages.microsoft.com/config/ubuntu/20.04/prod.list /etc/apt/sources.list.d/mssql-release.list

COPY dependencies.txt /root/dependencies.txt
# use space efficient utility from base image
RUN --mount=type=cache,target=/var/cache/apt \
    ACCEPT_EULA=Y /root/docker-apt-install.sh /root/dependencies.txt

# ACTION_EXEC sets the default executable for the entrypoint in the base-docker image
ENV VIRTUAL_ENV=/opt/venv/ \
    PATH="/opt/venv/bin:/opt/mssql-tools/bin:$PATH" \
    ACTION_EXEC=cohortextractor \
    PYTHONUNBUFFERED=True \
    PYTHONDONTWRITEBYTECODE=1 \
    PYSPARK_PYTHON=/opt/venv/bin/python \
    PYSPARK_DRIVER_PYTHON=/opt/venv/bin/python

#################################################
#
# Next, use the base-cohortextractor image to create a build image
FROM base-cohortextractor as builder

# install build time dependencies 
COPY build-dependencies.txt /root/build-dependencies.txt
RUN /root/docker-apt-install.sh /root/build-dependencies.txt

# install everything in venv for isolation from system python libraries
# hadolint ignore=DL3013,DL3042
RUN --mount=type=cache,target=/root/.cache \
    python3 -m venv /opt/venv && \
    /opt/venv/bin/python -m pip install -U pip setuptools wheel

RUN mkdir /app
WORKDIR /app

# We use a trick here to get faster local re-build times.
#
# cohortextractor's dependencies are listed in setup.py, and don't change very
# frequently. So, we COPY *just* setup.py and use a trick to install just the
# dependencies. That means docker won't rebuild this layer unless setup.py
# changes.
COPY setup.py setup.py
# hadolint ignore=DL3042
RUN --mount=type=cache,target=/root/.cache \
    python setup.py egg_info && \
    python -m pip install -r opensafely_cohort_extractor.egg-info/requires.txt

# Now we copy the full app. This means following steps will be re-run if *any*
# files in the project change (modulo .dockerignore), i.e. all the time.  But
# now, the previous cached step has pre-installed everything, so installing the
# project every time is much quicker
COPY . /app
# We install with --editible for two reasons
# 1) it allows later volume mounts to replace the installed code
# 2) we can easily edit code inside a docker image when debugging
#
# Also, we run `cohortextractor --help` at the end to force dependencies to
# import because the first time we import matplotlib we get a "generated new
# fontManager" message and we want to trigger that now rather than every time
# we run the docker image
# hadolint ignore=DL3042
RUN --mount=type=cache,target=/root/.cache \
    python -m pip install --editable /app && \
    cohortextractor --help


################################################
#
# Build the actual image from the base-python image
FROM base-cohortextractor as cohortextractor

# Some static metadata for this specific image, as defined by:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md#pre-defined-annotation-keys
# The org.opensafely.action label is used by the jobrunner to indicate this is
# an approved action image to run.
LABEL org.opencontainers.image.title="cohortextractor" \
      org.opencontainers.image.description="Cohortextractor action for opensafely.org" \
      org.opencontainers.image.source="https://github.com/opensafely-core/cohortextractor" \
      org.opensafely.action="cohortextractor"

RUN mkdir /workspace
WORKDIR /workspace

# copy venv over from builder image
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app


################################################
#
# Build dev image for running tests

FROM builder as cohortextractor-dev

VOLUME /app

# install dev dependencies
# hadolint ignore=DL3042
RUN --mount=type=cache,target=/root/.cache \
    python -m pip install -r /app/requirements.txt
