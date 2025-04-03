#!/usr/bin/python3
"""yaml config loader"""
import json
import os
import yaml

import arm.config.config_utils as config_utils

CONFIG_LOCATION = os.environ.get("CONFIGURATION_DIRECTORY", "/etc/arm/config").split(":")[0]
arm_config_path = os.path.join(CONFIG_LOCATION, "arm.yaml")
abcde_config_path = os.path.join(CONFIG_LOCATION, "abcde.conf")
apprise_config_path = os.path.join(CONFIG_LOCATION, "apprise.yaml")


def _load_config(fp):
    with open(fp, "r") as yaml_file:
        config = yaml.safe_load(yaml_file)
    return config


def _load_abcde(fp):
    with open(fp, "r") as abcde_read_file:
        config = abcde_read_file.read()
    return config


# arm config, open and read yaml contents
# handle arm.yaml migration here
# Load user config
cur_cfg = _load_config(arm_config_path)
# Load template config
arm_config = _load_config(os.path.join(cur_cfg['INSTALLPATH'], "setup/arm.yaml"))
is_read_only = False

# Environment variables as in systemd.exec(5)
# They take precedence over the yaml
if log_path := os.environ.get("LOGS_DIRECTORY", "").split(":")[0]:
    cur_cfg["LOGPATH"] = log_path
if state_path := os.environ.get("STATE_DIRECTORY", "").split(":")[0]:
    cur_cfg["DBFILE"] = os.path.join(state_path, "arm.db")

# Update the template config with the user's values
arm_config.update(cur_cfg)

try:
    # Save the dictionary
    with open(arm_config_path, "w") as settings_file:
        with open(
        os.path.join(cur_cfg["INSTALLPATH"], "arm/ui/comments.json"),
        "r",
    ) as comments_file:
            comments = json.load(comments_file)

        arm_cfg = comments['ARM_CFG_GROUPS']['BEGIN'] + "\n\n"
        for key, value in dict(arm_config).items():
            # Add any grouping comments
            arm_cfg += config_utils.arm_yaml_check_groups(comments, key)
            # Check for comments for this key in comments.json, add them if they exist
            try:
                arm_cfg += "\n" + comments[str(key)] + "\n" if comments[str(key)] != "" else ""
            except KeyError:
                arm_cfg += "\n"
            # test if key value is an int
            value = str(value)  # just change the type to keep things as expected
            try:
                post_value = int(value)
                arm_cfg += f"{key}: {post_value}\n"
            except ValueError:
                # Test if value is Boolean
                arm_cfg += config_utils.arm_yaml_test_bool(key, value)

        settings_file.write(arm_cfg)
        settings_file.close()
except OSError:
    is_read_only = True

# abcde config file, open and read contents
abcde_config = _load_abcde(abcde_config_path)

# apprise config, open and read yaml contents
apprise_config = _load_config(apprise_config_path)
