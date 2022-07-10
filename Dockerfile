# This Dockerfile uses multi-stage build to customize DEV and PROD images:
# https://docs.docker.com/develop/develop-images/multistage-build/
ARG GOOGLE_DISTROLESS_BASE_IMAGE="gcr.io/distroless/base"
ARG PYTHON_BUILDER_IMAGE=3.10-slim



## -------------- layer to give access to newer python + its dependencies ------------- ##


# Pull base image
FROM python:${PYTHON_BUILDER_IMAGE} as python-base
ARG NONROOT_USER="web"
ARG NONROOT_GROUP="web"
ARG NONROOT_UID=1000
ARG NONROOT_GID=1001

# Set python env vars
ENV PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    POETRY_HOME="/opt/poetry" \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_CACHE_DIR='/var/cache/pypoetry' \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    NONROOT_USER="${NONROOT_USER}" \
    NONROOT_GROUP="${NONROOT_GROUP}" \
    NONROOT_UID="${NONROOT_UID}" \
    NONROOT_GID="${NONROOT_GID}"

# Set path
ENV PATH="$POETRY_HOME/bin:$PATH"

# Install poetry
RUN apt-get update \
    && apt-get -y --no-install-recommends install curl \
    && curl -sSL https://install.python-poetry.org | python \
    && apt-get -y purge curl

RUN addgroup --gid ${NONROOT_GID} ${NONROOT_GROUP} \
    && adduser \
    --disabled-password \
    --gecos "" \
    --home /workspace \
    --ingroup ${NONROOT_GROUP} \
    --uid ${NONROOT_UID} \
    ${NONROOT_USER}

USER ${NONROOT_USER}
WORKDIR /workspace
# Copy only requirements, to cache them in docker layer
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP}  ./poetry.lock ./pyproject.toml  /workspace/


## -------------- build stage ------------- ##


FROM python-base AS python-build-stage
ENV APP_ENV="${APP_ENV}" \
    NONROOT_USER="${NONROOT_USER}" \
    NONROOT_GROUP="${NONROOT_GROUP}" \
    NONROOT_UID="${NONROOT_UID}" \
    NONROOT_GID="${NONROOT_GID}"
# Set shell pipefail
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
# Install dependencies and tidy up
RUN apt-get update \
    && apt-get -y install --no-install-recommends libpq-dev python3-dev build-essential \
    && poetry config virtualenvs.in-project true \
    && poetry install $(if [ $APP_ENV = 'production' ]; then echo '--no-dev'; fi) --no-root \
    # Cleaning poetry installation's cache for production:
    && if [ "$APP_ENV" = 'production' ]; then rm -rf "$POETRY_CACHE_DIR"; fi \
    && chown -Rf ${NONROOT_USER}:${NONROOT_GROUP} /workspace \
    && apt-get -y purge python3-dev build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER ${NONROOT_USER}
WORKDIR /workspace
# Copy files
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP} . ./
# Build app
RUN poetry build


## ------------------------------- distroless base image ------------------------------ ##

ARG APP_ENV
# build from distroless C or cc:debug, because lots of Python depends on C
FROM ${GOOGLE_DISTROLESS_BASE_IMAGE} as run-base

ENV APP_ENV=${APP_ENV}
ARG CHIPSET_ARCH="*64"

## ------------------------- copy python itself from builder -------------------------- ##

# this carries more risk than installing it fully, but makes the image a lot smaller
COPY --from=python-base /usr/local/lib/ /usr/local/lib/
COPY --from=python-base /usr/local/bin/python /usr/local/bin/python
COPY --from=python-base /etc/ld.so.cache /etc/ld.so.cache

## -------------------------- add common compiled libraries --------------------------- ##

# If seeing ImportErrors, check if in the python-base already and copy as below

# required by lots of packages - e.g. six, numpy, wsgi
COPY --from=python-base /lib/${CHIPSET_ARCH}/libz.so.1 /lib/${CHIPSET_ARCH}/
# required by google-cloud/grpcio
COPY --from=python-base /usr/lib/${CHIPSET_ARCH}/libffi* /usr/lib/${CHIPSET_ARCH}/
COPY --from=python-base /lib/${CHIPSET_ARCH}/libexpat* /lib/${CHIPSET_ARCH}/

## -------------------------------- non-root user setup ------------------------------- ##

COPY --from=python-base /bin/echo /bin/echo
COPY --from=python-base /bin/rm /bin/rm
COPY --from=python-base /bin/sh /bin/sh

RUN echo "${NONROOT_GROUP}:x:${NONROOT_GID}:${NONROOT_USER}" >> /etc/group
RUN echo "${NONROOT_GROUP}:x:${NONROOT_GID}:" >> /etc/group
RUN echo "${NONROOT_USER}:x:${NONROOT_UID}:${NONROOT_GID}::/workspace:" >> /etc/passwd

# quick validation that python still works whilst we have a shell
RUN python --version

# RUN rm /bin/sh /bin/echo /bin/rm

## --------------------------- standardise execution env ----------------------------- ##

COPY --chown=${NONROOT_USER}:${NONROOT_GROUP} --from=python-build-stage /workspace/.venv  /workspace/.venv
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP} --from=python-build-stage /workspace/dist  /workspace/dist
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP}  ./poetry.lock ./pyproject.toml  /workspace/
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP} . /workspace/
# default to running as non-root
USER ${NONROOT_USER}

# standardise on locale, don't generate .pyc, enable tracebacks on seg faults
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1

ENTRYPOINT ["/usr/local/bin/python"]
CMD ["-m","uvicorn","app:app","--reload","--log-level","info","--workers","1"]
