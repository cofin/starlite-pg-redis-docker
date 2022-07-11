# Standard Library
import multiprocessing
import platform

import typer

from app.cli.run import app as run_app

app = typer.Typer(help="_summary_")
app.add_typer(run_app)


@app.command()
def cli():
    """_summary_"""
    if platform.system() == "Darwin":
        multiprocessing.set_start_method("fork", force=True)
