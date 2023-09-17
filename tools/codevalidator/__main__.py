import argparse, pathlib, os, logging, yaml
from pathlib import Path

from .checker.checker import *
from .checker.tags import *

logger = logging.getLogger(__name__)

def find_config(filepath: pathlib.Path):
    for path in [x.joinpath(filepath) for x in [Path.cwd(), Path(os.path.dirname(__file__))]]:
        logger.debug(f'Checking {path}')
        if os.path.isfile(path):
            logger.debug(f'Found config file at {path}')
            return path

    raise FileNotFoundError('Could not find config file.')

def main():
    parser = argparse.ArgumentParser(
        prog='codevalidator',
        description='A modularized version of the check_greps.sh script. \
            This script checks for common mistakes in the codebase.')

    parser.add_argument(
        '-f', '--file',
        type=pathlib.Path,
        default='checks.yml',
        help='The file to read checks from.')

    parser.add_argument(
        '-d', '--debug',
        action='store_true',
        help='Enables debug logging. This will automatically enable when in CI mode and \
            when RUNNER_DEBUG is set.')

    parser.add_argument(
        '-c', '--ci',
        action='store_true',
        help='Run in GitHub CI mode. This will additionally print errors in workflow syntax. \
            The validator will also check for the GITHUB_ACTIONS environment variable, \
            and will automatically enable CI mode.')

    args = parser.parse_args()

    gh_ci = False
    debug_mode = False

    if args.ci or os.environ.get('GITHUB_ACTIONS'):
        gh_ci = True

    if args.debug or os.environ.get('RUNNER_DEBUG') and gh_ci:
        debug_mode = True

    if debug_mode:
        logging.basicConfig(level=logging.DEBUG)

    with open(find_config(args.file), 'r') as config_file:
        try:
            checks = yaml.safe_load(config_file)
        except yaml.YAMLError as exc:
            logger.error(f'Loading failure occurred: {exc}')
            if hasattr(exc, 'problem_mark'):
                mark = exc.problem_mark # type: ignore
                logger.error(f'Error position: ({mark.line + 1}, {mark.column + 1})')
            return 1

    logger.info('Running checks...')

    validator = CodeValidator(checks, gh_ci)

    try:
        validator.full_run()
    except ValidationError as e:
        logger.error(f'Validator failure occurred: {e}')
        return 1

    return 0 if len(validator.annotations) == 0 else 1

if __name__ == '__main__':
    exit(main())
