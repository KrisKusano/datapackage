function tests = datapackagetest
%% xUnit tests for datapackage function
% Kristofer D. Kusano - 6/28/14
tests = functiontests(localfunctions);
end

%% setup/teardown
function setupOnce(testCase)
% initial setup
clc

% add (absolute) datapackage dir to path
tstpath = fileparts(mfilename('fullpath'));
tstsplit = regexp(tstpath, filesep, 'split');
testCase.TestData.dpdir = fullfile(tstsplit{1:end-1});
end

function setup(testCase)
% reset path before each test
cd(fileparts(mfilename('fullpath')))

% add datapackage and jsonlab dir
addpath(testCase.TestData.dpdir);
addpath(fullfile(testCase.TestData.dpdir, 'jsonlab'));
end

function teardown(testCase)
if exist('datapackage.json', 'file')
    delete('datapackage.json');
end

if exist('data.csv', 'file')
    delete('data.csv');
end
end
%% Test Errors
function testjsonlab(testCase)
% temporarily rename jsonlab folder
from = fullfile(testCase.TestData.dpdir, 'jsonlab');
to = fullfile(testCase.TestData.dpdir, 'jsonlab_temp');
rmpath(from);

% for some reason matlab `movefile` does not fully execute until after
% the function call, causing an error...
if ispc
    move_str = ['MOVE "', from, '" "', to, '"'];
else
    move_str = ['mv "', from, '" "', to, '"'];
end
[~,~] = system(move_str); % supress output

% check for error
verifyError(testCase, @() datapackage(''), 'datapackage:jsonlabNotFound')

% clean up
movefile(to, from, 'f');
end

% TODO: I don't know how to test for 'datapackage:NoDataTables'

function testlocalfilenotfound(testCase)
% will not find 'datapackage.json' file in test dir
verifyError(testCase, @() datapackage('.'), 'datapackage:LocalFileDoesNotExist')
end

function testinlinedata(testCase)
% make datapackage with inline data
b = struct('name', 'testinline',...
           'resources', struct('data', 1:5));
fid = fopen('datapackage.json', 'w');
fprintf(fid, '%s', savejson('', b));
fclose(fid);

% try to open it
verifyError(testCase, @() datapackage('./'), 'datapackage:InLineData');
end

function testreqfield(testCase)
% make datapackage with resource with no required field
b = struct('name', 'testreqfield',...
           'resources', struct('crap', 1));
fid = fopen('datapackage.json', 'w');
fprintf(fid, '%s', savejson('', b));
fclose(fid);

% test
verifyError(testCase, @() datapackage('./'), 'datapackage:ResourceReqFields')
end

function testresourcepath(testCase)
% make datapackage with non-existant path and no url
b = struct('name', 'testresourcepath', ...
           'resources', struct('path', 'ozixjvoij'));
fid = fopen('datapackage.json', 'w');
fprintf(fid, '%s', savejson('', b));
fclose(fid);

% test
verifyError(testCase, @() datapackage('./'),...
            'datapackage:ResourcePathNotFound');
end

function errornvars(testCase)
% make datapackage with two column data
b = struct('name', 'testresourcepath', ...
           'resources', struct('path', 'data.csv',...
                               'schema', struct('fields',...
                                            struct('name', {'a', 'b'},...
                                            'type', {'number', 'number'}))...
                               )...
           );
fid = fopen('datapackage.json', 'w');
fprintf(fid, '%s', savejson('', b));
fclose(fid);

% make data with three column data
fid = fopen('data.csv', 'w');
fprintf(fid, '%s\n', 'a,b,c');
fclose(fid);
dlmwrite('data.csv', [1, 2, 3; 4, 5, 6], '-append')

% test
verifyError(testCase, @() datapackage('./'),...
            'datapackage:NVarsInSchemaDoNotMatch');
end

%% test function
function testsimple(testCase)
% make datapackage with two column data
b = struct('name', 'testresourcepath', ...
           'resources', struct('path', 'data.csv',...
                               'schema', struct('fields',...
                                            struct('name', {'a', 'b'},...
                                            'type', {'number', 'number'}))...
                               )...
           );
fid = fopen('datapackage.json', 'w');
fprintf(fid, '%s', savejson('', b));
fclose(fid);

% make data with two column data
fid = fopen('data.csv', 'w');
fprintf(fid, '%s\n', 'a,b');
fclose(fid);
dlmwrite('data.csv', [1, 2; 3, 4], '-append')

% read in
r = datapackage('./');
if istable(r)
    rmat = table2array(r);
else
    rmat = double(r);
end

% test
verifyEqual(testCase, rmat, [1, 2; 3, 4], 'data contents incorrect')
end

% TODO: need more complicated examples (on web, etc)