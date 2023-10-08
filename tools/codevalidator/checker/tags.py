import logging, yaml

_logger = logging.getLogger(__name__)

all(x % 2 == 0 for x in mylist)

class OptionMacro(yaml.YAMLObject):
    """
    Don't use this outside of this file. This exist purely to expand tags into a grep mapping.
    """
    option_name = ""
    yaml_loader = yaml.SafeLoader
    yaml_dumper = yaml.SafeDumper

    @classmethod
    def from_yaml(cls, loader: yaml.Loader, node):
        value = loader.construct_scalar(node)
        return {"options": cls.option_name, "grep": value}

class AsIs(OptionMacro):
    """
    Macro that specifies this grep should read the binary interpretation of this search.
    """
    yaml_tag = u'!asis'
    option_name = u'binary'

class Invert(OptionMacro):
    """
    Macro that specifies that this grep should list all lines that do not match this search.
    """
    yaml_tag = u'!invert'
    option_name = u'invert_match'

class IgnoreCase(OptionMacro):
    """
    Macro that specifies that this grep should ignore case sensitivity.
    """
    yaml_tag = u'!ignorecase'
    option_name = u'ignore_case'

class Files(yaml.YAMLObject):
    """
    Reference to a file set. Takes a key defined in `files` and replaces it with its values.
    """
    yaml_tag = u'!files'
    yaml_loader = yaml.SafeLoader
    yaml_dumper = yaml.SafeDumper

    def __init__(self, value):
        self.value = value

    def __str__(self) -> str:
        return f"!files {self.value}"

    def __repr__(self) -> str:
        return self.__str__()

    @classmethod
    def from_yaml(cls, loader: yaml.Loader, node):
        value = loader.construct_scalar(node)
        return cls(value)

    @classmethod
    def to_yaml(cls, dumper: yaml.Dumper, data):
        return dumper.represent_scalar(cls.yaml_tag, data.value)


class Piped(yaml.YAMLObject):
    """
    Indicates that a sequence of greps should pipe into one another.
    Best used with the `invert-match` option.
    """

    yaml_tag = u'!piped'
    yaml_loader = yaml.SafeLoader
    yaml_dumper = yaml.SafeDumper

    def __init__(self, value: list):
        self.greps = value

    @classmethod
    def from_yaml(cls, loader: yaml.Loader, node):
        return cls(loader.construct_sequence(node))

    @classmethod
    def to_yaml(cls, dumper: yaml.Dumper, data):
        return dumper.represent_sequence(cls.yaml_tag, data.value)
