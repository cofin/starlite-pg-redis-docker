ARG PYTHON_BUILDER_IMAGE=3.10-slim
# Pull base image
FROM python:${PYTHON_BUILDER_IMAGE} as python-base
ARG NONROOT_USER="web"
ARG NONROOT_GROUP="web"
ARG NONROOT_UID=1000
ARG NONROOT_GID=1001
ARG APP_ENV="development"
ARG APP_PATH="/workspace"
ARG VENV_PATH="/opt/venv"


# Set python env vars
ENV PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    POETRY_HOME="/opt/poetry" \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=0 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_CACHE_DIR='/var/cache/pypoetry' \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    NONROOT_USER="${NONROOT_USER}" \
    NONROOT_GROUP="${NONROOT_GROUP}" \
    NONROOT_UID="${NONROOT_UID}" \
    NONROOT_GID="${NONROOT_GID}" \
    APP_ENV="${APP_ENV}" \
    APP_PATH="${APP_PATH}" \
    VENV_PATH="${VENV_PATH}"

# Set path
ENV PATH="$POETRY_HOME/bin:$PATH:$VENV_PATH/bin"

# Set shell pipefail
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Install poetry
RUN apt-get update \
    && apt-get -y --no-install-recommends install curl \
    && curl -sSL https://install.python-poetry.org | python \
    && apt-get -y purge curl

RUN addgroup --gid ${NONROOT_GID} ${NONROOT_GROUP} \
    && adduser \
    --disabled-password \
    --gecos "" \
    --home ${APP_PATH} \
    --ingroup ${NONROOT_GROUP} \
    --uid ${NONROOT_UID} \
    ${NONROOT_USER}

WORKDIR ${APP_PATH}
# Copy only requirements, to cache them in docker layer
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP}  ./poetry.lock ./pyproject.toml  ${APP_PATH}


## -------------- build stage ------------- ##


FROM python-base AS python-build-stage

RUN python3 -m venv $VENV_PATH
# Install dependencies and tidy up
RUN apt-get update \
    && apt-get -y install --no-install-recommends libpq-dev python3-dev build-essential \
    && mkdir -p ${APP_PATH} \
    && chown -Rf ${NONROOT_USER}:${NONROOT_GROUP} ${APP_PATH} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p ${POETRY_CACHE_DIR} \
    && chown -Rf ${NONROOT_USER}:${NONROOT_GROUP} ${POETRY_CACHE_DIR} \
    && . ${VENV_PATH}/bin/activate \
    && poetry install $(if [ "$APP_ENV" = 'production' ]; then echo '--no-dev'; fi) --no-root \
    # Cleaning poetry installation's cache for production:
    && if [ "${APP_ENV}" = 'production' ]; then rm -rf "${POETRY_CACHE_DIR}"; fi

# Copy files
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP} . ./




## -------------- run stage ------------- ##
FROM python-base as python-run-stage
ARG APP_PATH
ARG VENV_PATH
ARG NONROOT_USER
ARG NONROOT_GROUP
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP} --from=python-build-stage ${VENV_PATH} ${VENV_PATH}
COPY --chown=${NONROOT_USER}:${NONROOT_GROUP} --from=python-build-stage ${APP_PATH} ${APP_PATH}
# default to running as non-root
USER ${NONROOT_USER}
# standardise on locale, don't generate .pyc, enable tracebacks on seg faults
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8
ENV PATH="$VENV_PATH/bin:$PATH"
ENTRYPOINT [ "python" ]
# todo: add a command to run the app instead of calling uvicorn directly
CMD ["-m", "uvicorn","app.main:app","--reload","--log-level","info","--workers","1"]
