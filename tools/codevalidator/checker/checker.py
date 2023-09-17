import logging, os
from typing import Any
from toposort import toposort_flatten, CircularDependencyError
from .tags import Files
from .types import *

_logger = logging.getLogger(__name__)

class CodeValidator():

    def __init__(self, checks: Any, gh_ci: bool) -> None:
        self.checks = checks
        self.is_gh_ci = gh_ci
        self.files: dict[str, list[str]] = dict()
        self.sections: dict[str, CVSection] = dict()
        self.annotations: list[str] = []
        self.directory = os.getcwd()

        _logger.debug(f'Initialized CodeValidator {"in GitHub CI mode" if gh_ci else ""}')
        _logger.debug(f'Assuming working directory: {self.directory}')

    def full_run(self) -> None:
        self.get_files()
        self.parse_checks()

    def get_files(self) -> None:
        self.files = self.__construct_file_list()

    def __construct_file_list(self) -> dict[str, list[str]]:
        _logger.debug(f'Constructing file list...')

        files_list = self.checks['files']
        res: dict[str, list[str]] = dict()

        if len(files_list) == 0:
            raise ValidationError('Files list is empty')

        graph: dict[str, set[str]] = dict()

        _logger.debug(f'Constructing dependency graph...')
        _logger.debug(f'Files list: {files_list}')

        for [key, files] in files_list.items():
            _logger.debug(f'Processing key: {key}')
            if isinstance(files, list):
                for file in files:
                    if not isinstance(file, Files):
                        continue
                    if not key in graph:
                        graph[key] = set()
                    graph[key].add(file.value)
            elif isinstance(files, Files):
                if not key in graph:
                    graph[key] = set()
                graph[key].add(files.value)
            elif not key in graph:
                graph[key] = set()

        try:
            toposorted = toposort_flatten(graph)
        except CircularDependencyError as e:
            raise ValidationError(f'Failed to construct files dependency graph: {e}')

        _logger.debug(f'Toposorted dependency graph: {toposorted}')

        for key in toposorted:
            res[key] = []
            files = files_list[key]
            if isinstance(files, list):
                for file in files:
                    if isinstance(file, Files):
                        res[key] += res[file.value]
                    elif isinstance(file, str):
                        res[key].append(file)
                    else:
                        raise ValidationError(f'Unknown type {type(file)} in sequence for files key {key}')
            elif isinstance(files, Files):
                res[key] = res[files.value]
            elif isinstance(files, str):
                res[key].append(files)
            else:
                raise ValidationError(f'Unknown type {type(files)} for files key {key}')

        _logger.debug(f'Constructed file list: {self.files}')

        return res

    def parse_checks(self) -> None:
        _logger.info(f'Parsing checks...')
        for [key, section] in self.checks['sections'].items():
            self.sections[key] = self.__parse_section(key, section)
        _logger.debug(f'Parsed checks, got: {self.sections}')

    def __parse_section(self, key, section: dict[str, Any]) -> CVSection:
        new_section = CVSection(key, section['section'])
        _logger.debug(f'Parsing section: {new_section}')
        new_section.checks = self.__parse_section_checks(section)
        _logger.debug(f'Parsed section, got: {new_section}')
        return new_section

    def __parse_section_checks(self, section: dict[str, Any]) -> list[CVCheck]:
        res: list[CVCheck] = []
        for [key, check] in section['checks'].items():
            new_check = CVCheck(key, [], [])
            _logger.debug(f'Parsing check key: {key}')
            new_check.files = self.__parse_check_files(check)
            new_check.greps = self.__parse_check_greps(check)
            _logger.debug(f'Parsed check, got: {new_check}')
            res.append(new_check)
        return res

    def __parse_check_files(self, check: dict[str, Any]) -> list[str]:
        _logger.debug(f'Parsing files for check: {check}')
        res: list[str] = []
        files = check['files']
        if isinstance(files, list):
            for file in files:
                if isinstance(file, Files):
                    res += self.files[file.value]
                elif isinstance(file, str):
                    res.append(file)
                else:
                    raise ValidationError(f'Unknown type {type(file)} in sequence for files key {files}')
        elif isinstance(files, Files):
            res = self.files[files.value]
        elif isinstance(files, str):
            res.append(files)
        else:
            raise ValidationError(f'Unknown type {type(files)} for files key {files}')
        _logger.debug(f'Parsed files, got: {res}')
        return res

    def __parse_check_greps(self, check: dict[str, Any]) -> list[Any]:
        _logger.debug(f'Parsing greps for check: {check}')

        res: list[Any] = []
        greps = check['greps']
        if isinstance(greps, list):
            for grep in greps:
                if isinstance(grep, dict):
                    res.append(grep)
                else:
                    raise ValidationError(f'Unknown type {type(grep)} in sequence for greps key {greps}')
        elif isinstance(greps, dict):
            res.append(greps)
        else:
            raise ValidationError(f'Unknown type {type(greps)} for greps key {greps}')

        _logger.debug(f'Parsed greps, got: {res}')

        return res
