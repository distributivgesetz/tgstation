import argparse, pathlib

def main():
    parser = argparse.ArgumentParser(
        prog="codevalidator",
        description="A modularized version of the check_greps.sh script. \
            This script checks for common mistakes in the codebase.",
    )

    parser.add_argument(
        "-f", "--file",
        type=pathlib.Path,
        default="./checks.yml",
        help="The file to read checks from.")

    args = parser.parse_args()

    print(args.file)

if __name__ == "__main__":
    main()
