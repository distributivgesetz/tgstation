import logging, yaml

_logger = logging.getLogger(__name__)

class SequenceTag(yaml.YAMLObject):
    yaml_loader = yaml.SafeLoader
    yaml_dumper = yaml.SafeDumper

class GrepDecoratorTag(yaml.YAMLObject):
    yaml_tag = u'!options'
    yaml_loader = yaml.SafeLoader
    yaml_dumper = yaml.SafeDumper

    def __init__(self, grep, options):
        self.grep = grep
        self.options = options

    def __str__(self) -> str:
        return f"!options {self.grep} {self.options}"

    def __repr__(self) -> str:
        return self.__str__()

    @classmethod
    def from_yaml(cls, loader: yaml.Loader, node):
        map = loader.construct_mapping(node)
        return cls(map['grep'], map['options'])

    @classmethod
    def to_yaml(cls, dumper: yaml.Dumper, data):
        return dumper.represent_mapping(cls.yaml_tag, {'grep': data.grep, 'options': data.options})

class GrepSimpleDecoratorTag(GrepDecoratorTag):
    option_name = None

    def __init__(self, grep):
        super().__init__(grep, self.option_name)

    def __str__(self) -> str:
        return f"!{self.option_name} {self.grep}"

# Macro for a file set.
class Files(yaml.YAMLObject):
    yaml_tag = u'!files'
    yaml_loader = yaml.SafeLoader
    yaml_dumper = yaml.SafeDumper

    def __init__(self, value):
        self.value = value

    def __str__(self) -> str:
        return f"!files {self.value}"

    def __repr__(self) -> str:
        return self.__str__()

# Specifies this grep to run with --binary.
class AsIs(GrepSimpleDecoratorTag):
    yaml_tag = u'!asis'

# Specifies this grep to run in inverted mode.
class Invert(GrepSimpleDecoratorTag):
    yaml_tag = u'!invert'

# Specifies this grep to ignore case.
class IgnoreCase(GrepSimpleDecoratorTag):
    yaml_tag = u'!ignorecase'

# Indicates that a grep should pipe into other greps in a sequence.
# Best used with the !invert tag.
class Piped(yaml.YAMLObject):
    yaml_tag = u'!piped'
    yaml_loader = yaml.SafeLoader
    yaml_dumper = yaml.SafeDumper

    def __init__(self, value: list):
        self.value = value

    @classmethod
    def from_yaml(cls, loader: yaml.Loader, node):
        return cls(loader.construct_sequence(node))

    @classmethod
    def to_yaml(cls, dumper: yaml.Dumper, data):
        return dumper.represent_sequence(cls.yaml_tag, data.value)
