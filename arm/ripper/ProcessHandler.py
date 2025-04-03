"""
Function definition
  Wrapper for the python subprocess module
"""
import logging
import subprocess


def arm_subprocess(cmd, in_shell, check=False):
    """
    Handle creating new subprocesses and catch any errors
    """
    arm_process = None
    logging.debug(f"Running command: {cmd}")
    try:
        arm_process = subprocess.check_output(
            cmd,
            shell=in_shell
        ).decode("utf-8")
    except subprocess.CalledProcessError as error:
        logging.error(f"Error while running command: {cmd}", exc_info=error)
        if decoded_output := error.output.decode("utf-8").strip():
            logging.error("Output was:")
            logging.error(decoded_output)
        else:
            logging.error("The command produced no output.")
        if check:
            raise error

    return arm_process
