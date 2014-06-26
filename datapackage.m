%% load dataprotocols.org Tabular Data Package into MATLAB table
%
% Kristofer D. Kusano - 6/14/14
function [data, meta] = datapackage(uri)
%%% Load data package and meta data from package%%%

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
%%% read a resource to a string from either a URL or local file %%%
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
%%% open the descriptor for the datapackage %%%
descriptor_string = open_resource([uri, 'datapackage.json']);
meta = loadjson(descriptor_string);
end

function data = get_resources(uri, meta, readfunc)
%%% open all resources as tables %%%
data = [];
if isfield(meta, 'resources') && ~isempty(meta.resources) 
    nr = length(meta.resources);
    data = cell(nr, 1);
    
    % import each resource
    for i = 1:nr
        % get resource, name
        r = meta.resources{i};
        if isfield(r, 'name')
            rname = r.name;
        else
            rname = 'UNKNOWN';
        end
        
        % where is the data located?
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
        elseif isfield(r, 'path')
            % check for local file
            if exist(fullfile(uri, r.path), 'file')
                fid = fopen(fullfile(uri, r.path));
                s = fscanf(fid, '%c');
                fclose(fid);
            elseif isfield(r, 'url')
                % has path, but file not found - get from URL
                s = urlread(r.url);
            else
                % TODO: check for uri/r.path combo available on web
                error('datapackage:ResourcePathNotFound',...
                    'Could not find path ''%s'' and no URL included',...
                    r.path);
            end
        elseif isfield(r, 'url')
            % download from internet
            s = urlread(r.url);
        end
        
        % get the data
        data{i} = parse_csv_from_string(s, readfunc);
        % import schema
    end
    
    % expand if only 1 resource
    if nr == 1
        data = data{1};
    end
end
end

function t = parse_csv_from_string(s, readfunc)
%%% a CSV from a string to a MATLAB table %%%
    % TODO: use input parser to implement optional read arguments ('ReadVariableNames' 'ReadRowNames' 'Delimiter' 'Format' 'TreatAsEmpty' 'HeaderLines')
    treatAsEmpty = '';
    delimiter = ',';
    format = '';
    
    % split by lines
    s = strrep(s, '\r', ''); % remove return carriage
    lines = regexp(s, '\n', 'split'); % split by lines
    lines(cellfun(@isempty, lines)) = []; % remove empty lines
    cells = cellfun(@(x) regexp(x, delimiter, 'split'), lines,...
        'uni', false); % split each line by ","
    
    % check and fix string qualifier (quote)
    qual = cellfun(@(x) length(regexp(x, '"')) > 1, lines); % lines with quote
    qlines = lines(qual);
    nq = length(qlines);
    qcell = cell(nq, 1);
    for i = 1:length(qlines)
        q = regexp(qlines{i}, '"'); % indicies of quote locations
        assert(mod(length(q), 2) == 0, 'unmatched text qualifier (i.e. ''"'')');
        
        % replace all internal "," with char(9) placeholder
        for j = 1:2:length(q)
            qlines{i}(q(j):q(j+1)) = strrep(qlines{i}(q(j):q(j+1)),...
                                            delimiter,...
                                            char(9));
        end
        
        % now split by ","
        qcell{i} = regexp(qlines{i}, delimiter, 'split');
        qcell{i} = cellfun(@(x) strrep(x, char(9), delimiter), qcell{i},...
            'uni', false); % place commas back in to text
        qcell{i} = cellfun(@(x) strrep(x, '"', ''), qcell{i},...
            'uni', false); % remove quotes
    end
    cells(qual) = qcell; % replace qualified text
    
    cell_len = cellfun(@length, cells); % length of each line
    if range(cell_len(2:end)) ~= 0
        error('datapackage:UnevenRows',...
            'rows in CSV string have uneven ammounts');
    end
    
    % check for column format (using first line)
    % this is how the MATLAB's table class does it
    % see:
    % open(fullfile(matlabroot, 'toolbox', 'matlab', 'datatypes', '@table', 'table.m'))
    % open(fullfile(matlabroot, 'toolbox', 'matlab', 'datatypes', '@table', 'readTextFile.m'))
    if isempty(format) && length(cells) > 1
        ncol = cell_len(2);
        row1 = cells{2};
        format = repmat('%f', 1, ncol); % format spec string
        for i = 1:ncol
            str = row1{i};
            num = str2double(str);
            if isnan(num)
                % If the result was NaN, figure out why.
                if isempty(str) || strcmpi(str,'nan') || any(strcmp(str,treatAsEmpty))
                    % NaN came from a nan string, and empty field, or one of the
                    % treatAsEmpty strings, treat this column as numeric.  Note that
                    % because we check str against treatAsEmpty, the latter only works
                    % on numeric columns.  That is what textscan does.
                    % TODO: isempty(str) could come from an empty string as well?
                    format(2*i) = 'f';
                else
                    % NaN must have come from a failed conversion, treat this column
                    % as strings.
                    format(2*i) = 'q';
                end
            else
                % Otherwise the conversion succeeded, treat this column as numeric.
                format(2*i) = 'f';
            end
        end
    end
    format = regexp(format, '%[a-zA-Z]', 'match');  % split into cell
   
    % combine and make data table
    cells_cat = vertcat(cells{2:end}); % data
    
    if strcmp(readfunc, 'table')
        t = cell2table(cells_cat);
    elseif strcmp(readfunc, 'dataset')
        t = cell2dataset(cells_cat);
    else
        error('datapackage:Invalidreadfunc',...
            'Invalid ''readfunc'' value');
    end
    
    % add headers to dataset
    headers = cells{1};
    if length(headers) == size(cells_cat, 2)
        if strcmp(readfunc, 'table')
            vname = 'VariableNames';
        elseif strcmp(readfunc, 'dataset')
            vname = 'VarNames';
        end
        t.Properties.(vname) = genvarname(headers);
    else
        warning('datapackage:HeaderLengthDifferent',...
            ['header length is not equal to width of data. ',...
             'Leaving column heads alone.'])
    end
end
    