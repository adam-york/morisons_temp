function tables = reportTables(results)
% REPORTTABLES Flatten a SegmentResult array into the three sheets
% written by excel_writer: attachment_calculation, attachment_summary,
% and summary.
%
%   tables = reportTables(results)
%
%   Tables are an OUTPUT FORMAT here, built only after every calculation
%   is finished. There is no summarisation step downstream of this
%   function that could misalign marine growth data with an elevation
%   band, because there is no calculation left to do once a table
%   exists.
%
%   Segments with no attachments are never constructed (see
%   Structure.hydrodynamicSegments), so the reported profile is
%   non-overlapping but may have gaps at elevations with nothing
%   mounted - it will never have overlaps.

    tables.attachment_calculation = attachmentCalculationTable(results);
    tables.attachment_summary = attachmentSummaryTable(results);
    tables.summary = summaryTable(results);
end

function calcTable = attachmentCalculationTable(results)
% One row per (segment, attachment, wave angle) - the finest-grained
% view, equivalent to the old "attachment_calculation" sheet.
%
% Difference from the pre-refactor sheet: Cd/Cm here are already
% quantity-weighted (see AttachmentContribution), where previously
% quantity weighting was applied later, downstream of this export. This
% is a deliberate consequence of resolving each attachment's
% contribution fully at calculation time.

    variableNames = {'lower_elevation', 'upper_elevation', ...
        'attachment_name', 'wave_angle', 'equivalent_cd', 'equivalent_cm'};

    rows = cell(1, 0);
    for i = 1:numel(results)
        result = results(i);
        for j = 1:numel(result.Contributions)
            c = result.Contributions(j);
            rows{end + 1} = table(result.Range.Lower, result.Range.Upper, ...
                c.AttachmentName, c.WaveAngle, c.Cd, c.Cm, ...
                'VariableNames', variableNames); %#ok<AGROW>
        end
    end

    if isempty(rows)
        % No segments (e.g. an empty attachments input): return a
        % correctly-typed, zero-row table rather than letting
        % vertcat(rows{:}) fail on an empty argument list.
        calcTable = table('Size', [0, numel(variableNames)], ...
            'VariableTypes', {'double', 'double', 'string', 'double', 'double', 'double'}, ...
            'VariableNames', variableNames);
    else
        calcTable = vertcat(rows{:});
    end
end

function summaryTable_ = attachmentSummaryTable(results)
% One row per segment: attachment-only worst-case Cd/Cm, summed across
% the attachments in the segment and maximised (independently - see
% analyseSegment) over heading. Equivalent to the old
% "attachment_summary" sheet.

    lower = arrayfun(@(r) r.Range.Lower, results)';
    upper = arrayfun(@(r) r.Range.Upper, results)';
    cd = [results.EquivalentCd]';
    cm = [results.EquivalentCm]';

    summaryTable_ = table(lower, upper, cd, cm, ...
        'VariableNames', {'lower_elevation', 'upper_elevation', 'equivalent_cd', 'equivalent_cm'});
end

function finalTable = summaryTable(results)
% One row per segment: the final structural equivalents. Equivalent to
% the old "summary" sheet.

    lower = arrayfun(@(r) r.Range.Lower, results)';
    upper = arrayfun(@(r) r.Range.Upper, results)';
    cd = [results.EquivalentCd]';
    cm = [results.EquivalentCm]';
    thickness = [results.AdditionalThickness]';
    cdD = [results.CdD]';

    finalTable = table(lower, upper, cd, cm, thickness, cdD, ...
        'VariableNames', {'lower_elevation', 'upper_elevation', 'equivalent_cd', ...
            'equivalent_cm', 'additional_thickness', 'cd_d'});
end
