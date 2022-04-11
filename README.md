# regen-revisits

This repository contains only code files and supporting files. It does not contain data. The data folder for this repository is located on Box: https://ucdavis.box.com/s/9ja36l3be9v9izimibdq9bd6x4rqsd6v

The scripts in this repo are set up so that all references to the data directory are relative, except for one file: `data_dir.txt`. You need to change the contents of this file so that it lists the root location of the data file.

The scripts in this repo source `convenience_functions.R`, which defines a function `datadir()`. If you pass this function a path to a file within the data directory, it prepends the path with the full path to the data directory. For example, on Derek's machine:

`datadir("CSEs/richter-db-export/Plot Data.xlsx")`
returns
`"/Users/derek/Documents/repo_data_local/regen-revisits_data/CSEs/richter-db-export/Plot Data.xlsx"`

This way, you don't need to hard-code the data directory location anywhere except in `data_dir.txt`, and other users only have to modify data_dir.txt in order to point to the location of the data directory on their machine.
