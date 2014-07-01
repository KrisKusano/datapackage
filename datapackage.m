%% load dataprotocols.org Tabular Data Package into MATLAB table (or dataset)
%
%   [data, meta] = DATAPACKAGE(uri) returns a table(s) that are contained in
%   the datapackage formatted files contained in the directory or HTTP uri.
%   A struct with the contents of the `datapackage.json` file is returned as
%   meta.
%
%   [data, meta] = DATAPACKAGE(uri, ...) passes the arguments ... to the 
%   `readtable` or `dataset` reading functions (e.g. 'headerlines', 'format', 
%   'ReadVariableNames', etc.)
%
%   If no optional functions are passed in, defaults for the `readtable` and 
%   `dataset` functions are used.
%
%   If there are more than one resource file in the datapackage, pass in
%   optional arguments as cell strings or arrays. For example:
%       ..., 'format', {'%f%q%f', '%f%f'}
%       ..., readvarnames, [false, true]
%
%   The cell string/array of optional arguments must be the same length as the 
%   number of resources to be read in. That is, if you specify optional
%   parameters for one resource, you must specify that parameter for all 
%   resources.
%
%   Examples:
%       Load a datapackage from the web:
%           % Note the trailing '/' is important!
%           [data, meta] = DATAPACKAGE('http://data.okfn.org/data/core/gdp/');
%
%       Load the same datapackage from a local directory:
%           % trailing '\' is here too!
%           [data, meta] = DATAPACKAGE('C:\path\to\package\')
%
%   Troubleshooting:
%       A common error is failure to read a numeric field (column) because of
%       non-numeric characters in the field. The error message will look
%       something like "Unable to read the entire file.  You may need to 
%       specify a different format string, delimiter, or number of header
%       lines." Further, there at the bottom of the error message there will be
%       a "Caused by:" messaged with "Reading failed at line 170." 
%       
%       To fix this read error, specify a 'format' name/value pair to the 
%       DATAPACAKGE function. The format '%f' is for a numeric (floating point)
%       field and use '%q' for a text field ('q' makes the textscan function
%       keep double quoted values together. If you are having trouble, read in
%       everything as a text field ('%q').
%
%   See Also: README.md loadjson
%
%   LICENSE:
%     Copyright (C) 2014 Kristofer D. Kusano
%
%     This program is free software; you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation; either version 2 of the License, or
%     (at your option) any later version.
% 
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details (LICENSE.txt).
function [data, meta] = datapackage(uri, varargin)
%% Load data package and meta data from package

% depends on jsonlab library
mpath = fileparts(mfilename('fullpath'));
jsonpath = fullfile(mpath, 'jsonlab');
if exist(jsonpath, 'file')
    addpath(fullfile(mpath, 'jsonlab'));
else
    error('datapackage:jsonlabNotFound',...
        'jsonlab directory %s does not exist', jsonpath);
end

% use table by default, fall back on dataset (statistics toolbox)
v = ver('MATLAB');
v = v.Version;
v = regexp(v, '\.', 'split');
v = cellfun(@str2double, v);
if v(1) >= 8 && v(2) >= 2
    readfunc = 'table';
elseif license('test', 'Statistics_Toolbox')
    readfunc = 'dataset';
else
    error('datapackage:NoDataTables',...
        ['Your version of MATLAB has neither ''readtable'' nor ''dataset'' ',...
         'functions. Upgrade to at least R2013b or get a license for the ',...
         'Statistics Toolbox'])
end
    
% extract meta data from descriptor file
meta = open_descriptor(uri);

% read resources
data = get_resources(uri, meta, readfunc, varargin{:});
end

function s = open_resource(path)
%% read a resource to a string from either a URL or local file
try
    s = urlread(path);
catch me
    if strcmp(me.identifier, 'MATLAB:urlread:InvalidUrl')
        try
            % try as a local file
            if exist(path, 'file')
                fid = fopen(path, 'r');
                s = fscanf(fid, '%c');
                fclose(fid);
            else
                error('datapackage:LocalFileDoesNotExist',...
                    'file %s is not on the MATLAB path', path)
            end
        catch err
            rethrow(err)
        end
    else
        rethrow(me)
    end
end
end

function meta = open_descriptor(uri)
%% open the descriptor for the datapackage
descriptor_string = open_resource([uri, 'datapackage.json']);
meta = loadjson(descriptor_string);
end

function data = get_resources(uri, meta, readfunc, varargin)
%% open all resources as tables

% parse input
p = inputParser;
p.CaseSensitive = false;  % default settings
p.PartialMatching = true;
addRequired(p, 'uri', @ischar);  % required args
addRequired(p, 'meta');
addRequired(p, 'readfunc', @ischar);
ischar_or_cellstr = @(x) ischar(x) || iscellstr(x);
addParameter(p, 'treatasempty', '', ischar_or_cellstr);  % optional args
addParameter(p, 'delimiter', ',', ischar_or_cellstr);
addParameter(p, 'headerlines', 1, @isnumeric);
addParameter(p, 'readvarnames', false, @islogical);
addParameter(p, 'format', '', ischar_or_cellstr);
parse(p, uri, meta, readfunc, varargin{:});  % do parse

treatasempty = p.Results.treatasempty;
delimiter = p.Results.delimiter;
headerlines = p.Results.headerlines;
readvarnames = p.Results.readvarnames;
format_str_input = p.Results.format;

% TODO: check for "primaryKey" in fields hash

data = [];
if isfield(meta, 'resources') && ~isempty(meta.resources) 
    nr = length(meta.resources);
    data = cell(nr, 1);
    
    if ~iscell(meta.resources)
        mr = {meta.resources};
    else
        mr = meta.resources;
    end
    
    % set up multiple read options
    if nr > 1
        % if using defaults, repeat
        usedef = @(x) any(strcmp(p.UsingDefaults, x));
        if usedef('treatasempty')
            treatasempty = repmat({treatasempty}, nr, 1);
        else
            assert(length(treatasempty) == nr,...
                '''treatasempty'' option must be same length as resources');
        end
        if usedef('delimiter')
            delimiter = repmat({delimiter}, nr, 1);
        else
            assert(length(delimiter) == nr,...
                '''delimiter'' option must be same length as resources');
        end
        if usedef('headerlines')
            headerlines = repmat(headerlines, nr, 1);
        else
            assert(length(headerlines) == nr,...
                '''headerlines'' option must be same length as resources');
        end
        if usedef('readvarnames')
            readvarnames = repmat(readvarnames, nr, 1);
        else
            assert(length(readvarnames) == nr,...
                '''readvarnames'' option must be same length as resources');
        end
        if usedef('format')
            format_str_input = repmat({format_str_input}, nr, 1);
        else
            assert(length(format) == nr,...
                '''format'' option must be same length as resources');
        end
    end
    
    % import each resource
    for i = 1:nr
        % get resource, name
        r = mr{i};
        if isfield(r, 'name')
            rname = r.name;
        else
            rname = 'UNKNOWN';
        end
        
        % resource must have at least one
        if ~isfield(r, 'data') && ...
                ~isfield(r, 'path') && ...
                ~isfield(r, 'url')
            error('datapackage:ResourceReqFields',...
                ['Resource number %d does not have a field ''data'', '...
                 '''path'', or ''url'''], i);
        end
        
        % where is the data located?
        cleanup_temp = false;
        if isfield(r, 'data')
            % inline data
            if isfield(r, 'format')
                % what format is the inline data in?
                if strcmpi(r.format, 'json')
                    inline_format = 'json';
                elseif strcmpi(r.format, 'csv')
                    inline_format = 'csv';
                else
                    inline_format = '';
                end
            end
            
            % TODO: read inline data
            error('datapackage:InLineData',...
                'resource ''%s'' has inline data...need to add to program',...
                rname) 
        else
            % external resource
            if isfield(r, 'path') && exist(fullfile(uri, r.path), 'file')
                % check for local file
                resource_path = fullfile(uri, r.path);
            elseif isfield(r, 'url')
                % has path, but file not found - get from URL
                s = urlread(r.url);
                resource_path = [tempname, '.csv'];
                cleanup_temp = true;
                fid = fopen(resource_path, 'w');  % save as temp file
                fprintf(fid, '%s', s);
                fclose(fid);
            else
                % TODO: check for uri/r.path combo available on web
                error('datapackage:ResourcePathNotFound',...
                    ['Either local path does not exist or no url for ',...
                     'resource %d'],...
                    i);
            end
        end
        
        % arguments for read functions
        if iscellstr(delimiter)
            rdelimiter = delimiter{i};
        else
            rdelimiter = delimiter;
        end
        
        if iscellstr(format_str_input)
            format_str = format_str_input{i};
        else
            format_str = format_str_input;
        end
        
        if length(headerlines) > 1
            rheaderlines = headerlines(i);
        else
            rheaderlines = headerlines;
        end
        
        if iscell(treatasempty) && ~iscellstr(treatasempty)
            rtreatasempty = treatasempty{i};
        else
            rtreatasempty = treatasempty;
        end
        
        if length(readvarnames) > 1
            rreadvarnames = readvarnames(i);
        else
            rreadvarnames = readvarnames;
        end
        
        % import schema, look for names/formats
        vnames = [];
        fieldtype = [];
        fieldformat = [];
        if isfield(r, 'schema')
            s = r.schema;
            if isfield(s, 'fields')
                f = s.fields;
                
                % iterate over all fields
                nf = length(f);
                vnames = cell(nf, 1);
                fieldtype = cell(nf, 1);
                fieldformat = cell(nf, 1);
                for j = 1:nf
                    if isfield(f{j}, 'name')
                        vnames{j} = f{j}.name;
                    end
                    if isfield(f{j}, 'type')
                        fieldtype{j} = f{j}.type;
                    end
                    if isfield(f{j}, 'format')
                        fieldformat{j} = f{j}.format;
                    end
                end
            end
        end
        
        % parse variable names
        if ~isempty(vnames)
            vempty = cellfun(@isempty, vnames);
            vempty_x = strcat('x', cellstr(num2str((1:sum(vempty))')));
            vnames(vempty) = vempty_x;
            vnames = cellfun(@genvarname, vnames, 'uni', false);
        end
        % check against first line
        fid = fopen(resource_path, 'r');
        raw = textscan(fid, '%s', 1,...
                         'headerlines', rheaderlines,...
                         'whitespace', '\n');
        fclose(fid);
        nvars_line1 = length(find(raw{1}{1} == rdelimiter)) + 1;
        
        nvars = nvars_line1;
        if ~isempty(vnames) && length(vnames) ~= nvars_line1
            nvars = max(nvars_line1, length(vnames));
            warning('datapackage:NVarsInSchemaDoNotMatch',...
                    ['Number of fields in schema (%d) does not match\n',...
                     'number of fields in 1st row of data file (%d)\n',...
                     'for resource %d. Using schema fields.\n',...
                     'You might need to specify a ''format'' option if\n',...
                     'there is a failure'],...
                    length(vnames), nvars, i);
        end
        
        % parse variable formats
        isdateformat = false(nvars, 1);
        isdatetimeformat = false(nvars, 1);
        if isempty(format_str) && ~isempty(fieldtype)
            format_str = repmat('%f', 1, nvars);
            for j = 1:nvars
                if strcmpi(fieldtype{j}, 'string')
                    format_str(2*j) = 'q';  % read, preserve double quote
                elseif strcmpi(fieldtype{j}, 'date')
                    format_str(2*j) = 'q';
                    isdateformat(j) = true;
                elseif strcmpi(fieldtype{j}, 'datetime')
                    format_str(2*j) = 'q';
                    isdatetimeformat(j) = true;
                elseif strcmpi(fieldtype{j}, 'object')
                    format_str(2*j) = 'q';
                    warning('''object'' format in resource ''%s''. Converting to string',...
                        r.name);
                elseif strcmpi(fieldtype{j}, 'geopoint') || strcmpi(fieldtype{j}, 'geojson')
                    format_str(2*j) = 'q';
                    warning('''geopoint'' format in resource ''%s''. Converting to string',...
                        r.name);
                elseif strcmpi(fieldtype{j}, 'array')
                    format_str(2*j) = 'q';
                    warning('''array'' format in resource ''%s''. Converting to string',...
                        r.name)
                end
            end
        end
        
        read_args = {
                     'delimiter', rdelimiter,...
                     'headerlines', rheaderlines,...
                     'treatasempty', rtreatasempty...
                     }; % common arguments
        if ~isempty(format_str)
            read_args = [read_args, {'format', format_str}];
        end
        
        % if no schema, read headers
        if isempty(vnames)
            warning(['No variable names found in resource schema %d. '...
                     'Attempting to read variable names from column heads'],...
                    i);
            rreadvarnames = true;
            iheaderlines = find(strcmpi(read_args, 'headerlines'));
            read_args{iheaderlines+1} = 0;
        end
        
        % read the data
        if strcmp(readfunc, 'table')
            data{i} = readtable(resource_path,...
                                'FileType', 'text',...
                                'ReadVariableNames', rreadvarnames,...
                                read_args{:} ...
                                );
            if ~isempty(vnames)
                data{i}.Properties.VariableNames = vnames;
            else
                vnames = data{i}.Properties.VariableNames;
            end
        elseif strcmp(readfunc, 'dataset')
            data{i} = dataset('File', resource_path,...
                              'readvarnames', rreadvarnames,...
                              'VarNames', vnames,...
                              read_args{:} ...
                              );
            if ~isempty(vnames)
                data{i}.Properties.VarNames = vnames;
            else
                vnames = data{i}.Properties.VarNames;
            end
        else
            error('datapackage:Invalidreadfunc',...
                'Invalid ''readfunc'' value');
        end
        
        % clean up
        if cleanup_temp
            delete(resource_path);
        end
        
        % convert date formats
        idate = find(isdateformat | isdatetimeformat);
        for j = 1:length(idate)
            try
                jdate = data{i}.(vnames{idate(j)});
                if ~isempty(fieldformat{idate(j)})
                    % use format, if it exists
                    jdateformat = fieldformat{idate(j)};
                    date_number = datenum(jdate, jdateformat);
                else
                    % no format, just try it
                    date_number = datenum(jdate);
                end
                data{i}.(vnames{idate(j)}) = date_number;
            catch
                % TODO: make a way for user to input date format
                warning(['Failed to parse field ''%s'' as a date string ',...
                         'in resource %d. Keeping it as a string'],...
                        vnames{j}, i);
            end
        end
    end
    
    % expand if only 1 resource
    if nr == 1
        data = data{1};
    end
end
end