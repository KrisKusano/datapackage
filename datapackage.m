%% load dataprotocols.org Tabular Data Package into MATLAB table
%
%   [data, meta] = DATAPACKAGE(uri) returns a table(s) that are contained in
%   the datapackage formatted files contained in the directory or HTTP uri.
%   A struct with the contents of the `datapackage.json` file is returned as
%   meta.
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
function [data, meta] = datapackage(uri)
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
data = get_resources(uri, meta, readfunc);
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

function data = get_resources(uri, meta, readfunc)
%% open all resources as tables

% TODO: use input parser to implement optional read arguments ('ReadVariableNames' 'ReadRowNames' 'Delimiter' 'Format' 'TreatAsEmpty' 'HeaderLines')
treatasempty = '';
delimiter = ',';
headerlines = 1;
readvarnames = false;
format_str = '';

data = [];
if isfield(meta, 'resources') && ~isempty(meta.resources) 
    nr = length(meta.resources);
    data = cell(nr, 1);
    
    if ~iscell(meta.resources)
        mr = {meta.resources};
    else
        mr = meta.resources;
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
                resource_path = tempname;
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
        
        % import schema, look for names/formats
        vnames = [];
        formats = [];
        if isfield(r, 'schema')
            s = r.schema;
            if isfield(s, 'fields')
                f = s.fields;
                
                % iterate over all fields
                nf = length(f);
                formats = cell(nf, 1);
                vnames = cell(nf, 1);
                for j = 1:nf
                    if isfield(f{j}, 'name')
                        vnames{j} = f{j}.name;
                    end
                    if isfield(f{j}, 'type')
                        formats{j} = f{j}.type;
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
                         'headerlines', headerlines,...
                         'whitespace', '\n');
        fclose(fid);
        nvars = length(find(raw{1}{1} == delimiter)) + 1;

        if ~isempty(vnames) && length(vnames) ~= nvars
            error('datapackage:NVarsInSchemaDoNotMatch',...
                  ['Number of variables in schema (%d) does not match ',...
                   'number of columns in 1st row of data file (%d) ',...
                   'for resource %d'],...
                  length(vnames), nvars, i);
        end

        % parse variable formats
        isdateformat = false(nvars, 1);
        isdatetimeformat = false(nvars, 1);
        if isempty(format_str) && ~isempty(formats)
            format_str = repmat('%f', 1, nvars);
            for j = 1:nvars
                if strcmpi(formats{j}, 'string')
                    format_str(2*j) = 'q';  % read, preserve double quote
                elseif strcmpi(formats{j}, 'date')
                    format_str(2*j) = 'q';
                    isdateformat(j) = true;
                elseif strcmpi(formats{j}, 'datetime')
                    format_str(2*j) = 'q';
                    isdatetimeformat(j) = true;
                elseif strcmpi(formats{j}, 'object')
                    format_str(2*j) = 'q';
                    warning('''object'' format in resource ''%s''. Converting to string',...
                        r.name);
                elseif strcmpi(formats{j}, 'geopoint') || strcmpi(formats{j}, 'geojson')
                    format_str(2*j) = 'q';
                    warning('''geopoint'' format in resource ''%s''. Converting to string',...
                        r.name);
                elseif strcmpi(formats{j}, 'array')
                    format_str(2*j) = 'q';
                    warning('''array'' format in resource ''%s''. Converting to string',...
                        r.name)
                end
            end
        end
        
        % arguments for read functions
        read_args = {
                     'delimiter', delimiter,...
                     'headerlines', headerlines,...
                     'treatasempty', treatasempty...
                     }; % common arguments
        if ~isempty(format_str)
            read_args = [read_args, {'format', format_str}];
        end
        
        % if no schema, read headers
        if isempty(vnames)
            warning(['No variable names found in resource schema %d. '...
                     'Attempting to read variable names from column heads'],...
                    i);
            readvarnames = true;
            iheaderlines = find(strcmpi(read_args, 'headerlines'));
            read_args{iheaderlines+1} = 0;
        end
        
        % read the data
        if strcmp(readfunc, 'table')
            data{i} = readtable(resource_path,...
                                'FileType', 'text',...
                                'ReadVariableNames', readvarnames,...
                                read_args{:} ...
                                );
            if ~isempty(vnames)
                data{i}.Properties.VariableNames = vnames;
            end
        elseif strcmp(readfunc, 'dataset')
            data{i} = dataset('File', resource_path,...
                              'readvarnames', readvarnames,...
                              'VarNames', vnames,...
                              read_args{:} ...
                              );
            if ~isempty(vnames)
                data{i}.Properties.VarNames = vnames;
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
                data{i}(:, idate(j)) = datenum(data{i}(:, idate(j)));
            catch
                % TODO: make a way for user to input date format
                warning(['Failed to parse field ''%s'' as a date string. ',...
                         'Keeping it as a string'],...
                        vnames{j});
            end
        end
    end
    
    % expand if only 1 resource
    if nr == 1
        data = data{1};
    end
end
end