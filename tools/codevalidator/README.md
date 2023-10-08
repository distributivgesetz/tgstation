# Code Validator

This is a modularized (and overengineered) version of the `check_greps.sh` script. At its core, it just runs Regular Expressions with `ripgrep` on the code files to inform programmers about common mistakes (eg. formatting errors). 

## How To Use

Using the module is quite simple; simply calling `tools/bootstrap/python -m codevalidator -f <your checks file>.yml` is enough in most cases. All regular expressions are interpreted from a config.yml file that (ab)uses YAML syntax to make the checks a little easier to read. 

## The Config File

The meat of the execution is controlled by the config file. It defines all the regexes, as well as the files they are supposed to run on and a hint message that's printed to the user (referring to this as a "check" from now on). A config file defines two things at the top level: file directories, and sections. 

### Files

Files are defined by a key (in `snake_case`) and a list of paths to files that should be checked, or other files keys. These paths follow the format of directories you would usually pass to grep. You can reference other files by using the `!files` tag, which I will go into detail below.

*Files are defined like this:*

```yml
files:
  files_one:
    - path/to/files_one/**
  files_two:
    - path/to/files_two/**
  all_files:
    - !files files_one
    - !files files_two
    - some/more/files/**
```

### Sections

The `sections` is made up of a sequence of sections, containing a name and a mapping of checks. This is used to categorize checks, with categories such as "Code Quality", "Map Issues", "Spelling Mistakes" and so on.

*Sections are defined like this:*

```yml
sections:
  - name: Some common mistakes
    checks: 
      check_one: <...>
      check_two: <...>

  - name: Some more common mistakes
    checks: <...>
```

### Checks

The `checks` mapping is where checks are actually defined. Each check has a key unique to their section (in `kebab-case`), and is made up of `greps`, a list of `files` that need to be checked, and a `message` to be printed should the check detect an error.

*Example:*

```yml
john-check:
  greps: \t*name = "John(?:\s\w)?"
  files:
    - !files code_files
  message: >
    Entity named John found in code, please come up with a more creative name
```

`greps` should contain either one or more regular expressions to be executed. These regular expressions can be just a normal string, or they can be an object made up of a list of `options` and a `grep` string containing the regex itself. `options` can be used to pass  command line parameters for more fine-grained control. There are also short-hands for command line parameters, explained below.

*Example:*

```yml
greps:
  - grep: one # It's not valid to use a short-hand here
    options: v;i
  - !ignorecase two # Here you may use a short-hand
```

## Tags

The code validator implements certain tags to make writing checks easier, and to reduce code duplication. There is a tag for referring back to previously defined files, and there are tags that act as "macros" for common command line options.

### The `!files` tag

This tag just acts as a reference to a set of file paths defined in `files`. This is very useful, since you can define paths once, and then you're able to refer back to them again via their key. Code validator also allows file definitions to reference eachother. 

### `!asis`, `!ignorecase` and `!invert`

These tags are basically short-hand implementations of common options, so you don't have to type out a full mapping just to enable one command line option. 

Due to limitations in YAML, you can only use one at a time. If you need more options enabled, then consider using a mapping.

### The `!piped` tag

This tag tells the validator to parse the next sequence of greps together whilst piping the results of one query into the next. This is very useful in combination with `!invert` for setting up a "filter", where you use a general matcher for invalid uses of something and weed out the implementations that are actually valid.

## Putting everything together in one file

Now that you know almost everything you need to know about writing a checks config, we can apply it with an example. Let's say we want to write a checks file that flags all names which start with `John`. The files that we need to check are `code/**/**.dm` and `_maps/**/**.dmm`. There's two exceptions though; we need to leave `John Mapper` in maps alone because he's too soulful to remove, and we are absolutely sure that we don't need to check `code/**/johnless/**.dm` because - as the directory indicates - coders will *never ever* add a John into these files. Ever.

We will start with the files first, like so:

```yml
files:
	code_files:
		- code/**/**.dm
		- code/**/johnless/!**.dm
	map_files:
		- _maps/**/**.dmm

sections: ~ # TODO
```

Rest is Work In Progress
