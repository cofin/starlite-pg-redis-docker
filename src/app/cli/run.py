# Standard Library
import multiprocessing
import platform

import typer

app = typer.Typer()


@app.command()
def run(dev_mode: bool = False):
    """_summary_"""
    if dev_mode:
        typer.echo("Running in dev mode")
    if platform.system() == "Darwin":
        multiprocessing.set_start_method("fork", force=True)
