"""
Function definition
  Wrapper for the python subprocess module
"""
import logging
import subprocess
from typing import Optional, List


def arm_subprocess(cmd: str | List[str], shell=False, check=False) -> Optional[str]:
    """
    Spawn blocking subprocess

    :param cmd: Command to run
    :param shell: Run ``cmd`` in a shell
    :param check: Raise ``CalledProcessError`` if ``cmd`` returns non-zero exit code

    :return: Output (both stdout and stderr) of ``cmd``, or ``None`` if it returned a non-zero exit code

    :raise CalledProcessError:
    """
    arm_process = None
    logging.debug(f"Running command: {cmd}")
    try:
        arm_process = subprocess.check_output(
            cmd,
            shell=shell,
            stderr=subprocess.STDOUT,
            encoding="utf-8"
        )
    except (subprocess.CalledProcessError, OSError) as error:
        logging.error(f"Error while running command: {cmd}", exc_info=error)
        if decoded_output := error.output.strip():
            logging.error(f"Output was: {decoded_output}")
        else:
            logging.error("The command produced no output.")
        if check:
            raise error

    return arm_process
