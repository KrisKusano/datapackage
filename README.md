# datapackage (MATLAB)
a MATLAB function to read datapackage formatted data

## Datapackage Description
The MATLAB function `datapackage` reads in formatted data that conforms
to the
[dataprotocols.org](http://dataprotocols.org/tabular-data-package/)
tabular data standard. The standard is designed to be easily transmitted over HTTP or
be saved on a local disk.

In short, a tabular data package contains two or more files:
* `datapackage.json`
* one or more tabular data files in [CSV
  format](http://dataprotocols.org/tabular-data-package/#csv-files)

The `datapackage.json` file contains meta information pertaining to the
data files, including:
* dataset name, description, and license
* description of data files
  - data fields (column) information (name, type)

## Install
This is a development library, including a dependent JSON library.
In order to install run the following:
```
git clone https://github.com/KrisKusano/datapackage.git
git submodule init
git submodule update
```

Because MATLAB has no native JSON reader, this project uses the open
source `jsonlab` function `loadjson` (and the unit tests use
`savejson`). The project home page can be found
[here](http://iso2mesh.sourceforge.net/cgi-bin/index.cgi?jsonlab).

## MATLAB Function Description
The `datapackage` function reads formatted data from either a URL or
local file path. The function first reads searches for the
`datapackage.json` file, which determines which files will be loaded.

Since MATLAB R2013b, the
[table](http://www.mathworks.com/help/matlab/tables.html) data type has been included in base MATLAB. Previously, the [dataset](http://www.mathworks.com/help/stats/dataset-class.html) was included in the MATLAB Statistics Toolbox. The `datapackage` function will default to returning a `table` object. If the MATLAB release is before R2013b, the `datapackage` function will return a `dataset` object. If neither `table` nor `dataset` is available, the function will return an error.

## Limitations
* In-line data, that is contained in the `datapackage.json` file, is not
  supported. It is not clear if this is even allowed per the standard:
  > All data files MUST be in CSV format
* The field (column) attribute types `date` and `datetime` are converted
  to a MATLAB numerical date format using the built-in `datenum` function
  convert a number string. The call to `datenum` has no format string
  specified, so it seems like it is quite likely to give up. In this
  case, the function keeps the date as a string.

## Testing
Unit tests are contained in the file `./tests/datapackagetest.m`. The
unit tests use MATLAB's built-in [unit test
framework](http://www.mathworks.com/help/matlab/matlab-unit-test-framework.html).
To run the tests, run the following from within the `./tests/`
directory:
```
results = runtests('datapackagetest.m');
```
If there is minimal printout to the command window, then all tests
passed.

## License
This code is provided under the [GNU General Public License (GPL)
version 2](https://www.gnu.org/licenses/gpl-2.0.txt). 
