%% try reading in all core data packages from okfn.org
% Note: requires internet connection
% Kristofer D. Kusano - 6/29/14
clear all;
clc;
%% Download core datasets from website (uncomment to regenerate list)
% disp('downloading core datapackage list from http://data.okfn.org/data');
% s = urlread('http://data.okfn.org/data');
% 
% % get core datapackage links (accessed 6/29/14 - 19 core datasets)
% % uncomment to regenerate list in future
% a_tags = regexp(s, '<a([^>]+)>(.+?)</a>', 'match');  % all <a> tags
% a_crep = a_tags(~cellfun(@isempty, regexp(a_tags, '/data/core')));  % only core
% a_core = a_crep(1:2:end);  % each shows up twice
% core = cellfun(@(x) x{1}{1},...
%                regexp(a_core, 'href="(.*)"', 'tokens'),...
%                'uni', false);
% a_html = strcat('http://data.okfn.org', core, '/');
% 
% % print out
% fprintf('core_list = {\n')
% fprintf('''%s''\n', a_html{:})
% fprintf('};\n')
%% Core dataset list
core_list = {
                'http://data.okfn.org/data/core/bond-yields-uk-10y/'
                'http://data.okfn.org/data/core/bond-yields-us-10y/'
                'http://data.okfn.org/data/core/co2-fossil-global/'
                'http://data.okfn.org/data/core/cofog/'
                'http://data.okfn.org/data/core/cpi/'
                'http://data.okfn.org/data/core/country-codes/'
                'http://data.okfn.org/data/core/country-list/'
                'http://data.okfn.org/data/core/currency-codes/'
                'http://data.okfn.org/data/core/cpi-us/'
                'http://data.okfn.org/data/core/finance-vix/'
                'http://data.okfn.org/data/core/gdp-us/'
                'http://data.okfn.org/data/core/gdp-uk/'
                'http://data.okfn.org/data/core/gdp/'
                'http://data.okfn.org/data/core/gold-prices/'
                'http://data.okfn.org/data/core/house-prices-uk/'
                'http://data.okfn.org/data/core/house-prices-us/'
                'http://data.okfn.org/data/core/investor-flow-of-funds-us/'
                'http://data.okfn.org/data/core/population/'
                'http://data.okfn.org/data/core/s-and-p-500/'
                'http://data.okfn.org/data/core/s-and-p-500-companies/'
            };
expect_failure = [6];  % 'http://data.okfn.org/data/core/country-codes/'
%% Test load all of them
evalc('rmpath(''..'');'); % evaluate silently
evalc('rmpath(''../bin'');');

addpath('..');  % development version
% addpath('../bin');  % switch to release version - need to unzip first

dp_loc = which('datapackage');

if isempty(dp_loc)
    error('''datapackage'' function is not on path');
end

n = length(core_list);
idxfail = false(1, n);  % mark failures

fprintf('Trying to load all %d core datapackages with default options\n', n);
fprintf('(expecting %d failures)\n\n', length(expect_failure));
fprintf('Using function located at ''%s''\n\n', dp_loc);

for i = 1:n
    fprintf('Datapackage ''%s'' (%d of %d)\n',...
            core_list{i}, i, n);
    try
        [d, m] = datapackage(core_list{i});
    catch me
        fprintf(2, '%s\n', getReport(me));
        idxfail(i) = true;
    end
end

fprintf('\nDone testing. %d failures\n\n', sum(idxfail));
assert(sum(idxfail) == length(expect_failure),...
       'Expecting %d failures, found %d', length(expect_failure), sum(idxfail));
assert(all(find(idxfail) == expect_failure),...
       'Unexpected failure...check find(idxfail) and expect_failure');
%% Expecting 2 failures - try additional arguments
disp('Checking 1 trouble cases');

% 'Country Codes' datapackage
% value in "Palestine, State of" row (169) for column GAUL (13) is not 
% an int ("91 267" has a space in it)
% works by reading as string
itrouble = 6;
fprintf('Datapackage ''%s''...', core_list{itrouble});
fm = repmat('%q', 1, 20);
fm(2*[5, 17, 19]) = 'f';
[d, m] = datapackage(core_list{itrouble},...
                     'format', fm);
disp('success');

fprintf('\n\nALL TESTS COMPLETE...PASSED\n\n')
