from typing import Any

class ValidationError(ValueError):
    pass

class CVOption():
    def __init__(self, key: str, value: Any) -> None:
        self.key = key
        self.value = value

    def __str__(self) -> str:
        return f'CVOption(key={self.key}, value={self.value})'

    def __repr__(self) -> str:
        return self.__str__()

class CVGrep():
    def __init__(self, key: str, grep: str, options: list[CVOption] = []) -> None:
        self.key = key
        self.grep = grep
        self.options = options

    def __str__(self) -> str:
        return f'CVGrep(key={self.key}, grep={self.grep}, options={self.options})'

    def __repr__(self) -> str:
        return self.__str__()

class CVGrepPipe():
    def __init__(self, greps: list[CVGrep]) -> None:
        self.greps = greps

    def

    def __str__(self) -> str:
        return f'CVGrepPipe(greps={self.greps})'

    def __repr__(self) -> str:
        return self.__str__()

class CVCheck():
    def __init__(self, key: str, files: list[str], greps: list[CVGrep] = []) -> None:
        self.key = key
        self.files = files
        self.greps = greps

    def __str__(self) -> str:
        return f'CVCheck(key={self.key}, files={self.files}, greps={self.greps})'

    def __repr__(self) -> str:
        return self.__str__()

class CVSection():
    def __init__(self, key: str, name: str, checks: list[CVCheck] = []) -> None:
        self.key = key
        self.name = name
        self.checks = checks

    def __str__(self) -> str:
        return f'CVSection(key={self.key}, name={self.name}, checks={self.checks})'

    def __repr__(self) -> str:
        return self.__str__()
