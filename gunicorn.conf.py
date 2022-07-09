from app.config import gunicorn_settings
from app.logging import log_config

# Gunicorn config variables
accesslog = gunicorn_settings.ACCESS_LOG
bind = f"{gunicorn_settings.HOST}:{gunicorn_settings.PORT}"
errorlog = gunicorn_settings.ERROR_LOG
keepalive = gunicorn_settings.KEEPALIVE
logconfig_dict = log_config.dict(exclude_none=True)
loglevel = gunicorn_settings.LOG_LEVEL
reload = gunicorn_settings.RELOAD
threads = gunicorn_settings.THREADS
timeout = gunicorn_settings.TIMEOUT
worker_class = gunicorn_settings.WORKER_CLASS
workers = gunicorn_settings.WORKERS
preload = gunicorn_settings.PRELOAD


# Server hooks
#
#   post_fork - Called just after a worker has been forked.
#
#       A callable that takes a server and worker instance
#       as arguments.
#
#   pre_fork - Called just prior to forking the worker subprocess.
#
#       A callable that accepts the same arguments as after_fork
#
#   pre_exec - Called just prior to forking off a secondary
#       master process during things like config reloading.
#
#       A callable that takes a server instance as the sole argument.


def post_fork(server, worker):  # pylint: disable=unused-argument
    """Execute after a worker is forked."""


def pre_fork(server, worker):  # pylint: disable=unused-argument
    """Execute before a worker is forked."""


def pre_exec(server):  # pylint: disable=unused-argument
    """Execute before a new master process is forked."""


def when_ready(server):  # pylint: disable=unused-argument
    """Execute just after the server is started."""


def worker_int(worker):  # pylint: disable=unused-argument
    """Execute just after a worker exited on SIGINT or SIGQUIT."""


def worker_abort(worker):  # pylint: disable=unused-argument
    """Execute when worker received the SIGABRT signal."""


def on_exit(server):  # pylint: disable=unused-argument
    """Execute just before exiting."""


def post_worker_init(worker):  # pylint: disable=unused-argument
    """Execute after a worker has initialized."""
