#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

"""Insert BlueCSR's generated register table into the README."""

from pathlib import Path
import sys


generated_path, readme_path = map(Path, sys.argv[1:])
begin = "<!-- BEGIN GENERATED CSR MAP -->"
end = "<!-- END GENERATED CSR MAP -->"
readme = readme_path.read_text()
before, remainder = readme.split(begin, 1)
_, after = remainder.split(end, 1)

# The README already supplies the section title.
_, table = generated_path.read_text().split("\n\n", 1)
readme_path.write_text(f"{before}{begin}\n\n{table.rstrip()}\n\n{end}{after}")
