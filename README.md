# datapackage (MATLAB)
a MATLAB function to read data package formatted data

## Tabular Data Package Description
The MATLAB function `datapackage` reads in formatted data that conforms
to the
[dataprotocols.org tabular data standard](http://dataprotocols.org/tabular-data-package/).
The standard is designed to be easily transmitted over HTTP or be saved on a local disk.

In short, a tabular data package contains two or more files:
* `datapackage.json`
* one or more tabular data files in [CSV
  format](http://dataprotocols.org/tabular-data-package/#csv-files)

The `datapackage.json` file contains meta information pertaining to the
data files, including:
* dataset name, description, and license
* description of data files
  - data fields (column) information (e.g. name, type)

Examples of data distributed in datapackage format can be found from the
[Open Knowledge Foundation](http://data.okfn.org/).

## Getting the `datapackage` MATLAB function
To use the `datapackage` function:

1. Download from the file from the
   [MATLAB Central File
   Exchange](http://www.mathworks.com/matlabcentral/fileexchange/47506-read-tabular-data-package).
2. Unzip the file and place the file `datapackage.m` on your MATLAB path
   (e.g. your `My Documents/MATLAB` folder on Windows).
3. Use the function (see [examples
   below](#matlab-function-description-and-examples)).

This GitHub repo is a development library. To contribute fork this repo.
See [instruction for the development version,
below](#getting-the-development-version).

### MATLAB Function Description and Examples
The `datapackage` function reads formatted data from either a URL or
local file path. The function first searches for the
`datapackage.json` file, which determines which `CSV` files will be loaded.

For example, you can download a datapackage off the web:

```MATLAB
% Note, the trailing "/" is important
[data, meta] = datapackage('http://data.okfn.org/data/core/gdp/');
```

You can load a `datapackage` locally:

```MATLAB
% The trailing "/" is also important
[data, meta] = datapackage('C:\path\to\package\');
```

### Limitations
* In-line data, that is contained in the `datapackage.json` file, is not
  supported. It is not clear if this is even allowed per the standard:

  > All data files MUST be in CSV format

* The field (column) attribute types `date` and `datetime` are converted
  to a MATLAB numerical date format using the built-in `datenum` function
  convert a number string. The call to `datenum` has no format string
  specified, so it seems like it is quite likely to give up. In this
  case, the function keeps the date as a string.
* Quote characters in CSV files other than the double quote (") are not
  supported. This is because the underlying MATLAB function (`textscan`)
  has no facility for this.

* Since MATLAB R2013b, the
  [table](http://www.mathworks.com/help/matlab/tables.html) data type
  has been included in base MATLAB. Previously, the
  [dataset](http://www.mathworks.com/help/stats/dataset-class.html) was
  included in the MATLAB Statistics Toolbox. The `datapackage` function
  will default to returning a `table` object. If the MATLAB release is
  before R2013b, the `datapackage` function will return a `dataset` object.
  If neither `table` nor `dataset` is available, the function will return
  an error.

## Getting the development version
This repo is a development library, including a dependent JSON library
(JSONLab)

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

### Making the MATLAB Central zip
The file for download from the MATLAB Central File Exchange website is
made by running `make`. The `makefile` combines the `datapackage.m` file
with the `loadjson.m` file from `jsonlab` and creates a zip with the
license in the `bin/` directory.


### Testing
#### Unit Tests
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

#### Core Data package Testing
In addition to unit testing, the file `./tests/coredatasetstests.m`
attempts to load the 20 "core" [data package
sets](http://data.okfn.org/data). First, all files are read in using
default settings (no optional name/value pairs). At the time of writing,
one data packages requires additional name/value pairs in order to avoid
errors.

## License
The MATLAB Central File Exchange and this source code are distributed
under the [BSD-2 License](LICENSE.txt).

