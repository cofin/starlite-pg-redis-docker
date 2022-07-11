#!/usr/bin/env python3
import sys
from pathlib import Path

# Third Party Libraries
from rich.console import Console

console = Console(
    markup=True,
)


def main() -> None:
    """Loads CLI application for Gluent Console."""
    current_path = Path(__file__).parent.resolve()
    sys.path.append(str(current_path))
    try:
        # Gluent
        from app.cli import app as cli  # pylint: disable=import-outside-toplevel

        cli()
    except ImportError:
        console.log(
            "💣 [bold red] Could not load required libraries.  ",
            "Please check your Gluent Enterprise Console installation",
        )


if __name__ == "__main__":
    main()
