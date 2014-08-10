# copy files, make zip to upload to MATLAB Central File Exchange

all: bin/datapackage.zip clean

bin/datapackage.zip: bin/datapackage.m bin/LICENSE.txt
	rm -f datapackage.zip
	cd bin; zip datapackage.zip datapackage.m LICENSE.txt

bin/datapackage.m: bin/jsonlab.m
	cat datapackage.m bin/jsonlab.m > bin/datapackage.m

bin/jsonlab.m: bin/ jsonlab/loadjson.m
	cat jsonlab/loadjson.m jsonlab/varargin2struct.m jsonlab/jsonopt.m > bin/jsonlab.m

bin/LICENSE.txt: bin/
	cp LICENSE.txt bin/LICENSE.txt

bin/:
	mkdir -p bin

jsonlab/loadjson.m:
	git submodule init
	git submodule update

clean:
	rm -f bin/datapackage.m bin/LICENSE.txt bin/jsonlab.m
