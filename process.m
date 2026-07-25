function process(attachmentsTable, marineGrowthTable, settings)
% PROCESS Run the full Morison Cd/Cm pipeline.
%
%   process(attachmentsTable, marineGrowthTable)
%   process(attachmentsTable, marineGrowthTable, settings)
%
%   attachmentsTable must have columns:
%       lower_elevation, upper_elevation, attachment_name,
%       member_outer_diameter, attachment_outer_diameter,
%       centre_to_centre_distance, attachment_angle, quantity
%
%   marineGrowthTable must have columns:
%       lower_elevation, upper_elevation, mp_drag_coeff,
%       mp_inertia_coeff, marine_growth_thickness
%
%   NOTE ON INPUT SCHEMA: member_outer_diameter now belongs to the
%   attachments sheet, not the marine growth sheet (it used to be
%   mp_outer_diameter on marine_growth_table). It is fixed member
%   geometry, not a marine growth property - see morison.Attachment for
%   the reasoning. Existing input workbooks need this column moved.
%
%   The structure is partitioned into HydrodynamicSegments at every
%   marine growth AND attachment boundary (see
%   morison.Structure.hydrodynamicSegments), so marine growth properties
%   are resolved exactly once per segment and never duplicated or
%   re-looked-up downstream of that point.

    arguments
        attachmentsTable   table
        marineGrowthTable  table
        settings (1,1) morison.AnalysisSettings = morison.AnalysisSettings()
    end

    structure = buildStructure(attachmentsTable, marineGrowthTable);
    segments = structure.hydrodynamicSegments();

    results = morison.SegmentResult.empty(1, 0);
    for i = 1:numel(segments)
        results(end + 1) = morison.analyseSegment(segments(i), settings); %#ok<AGROW>
    end

    reportedTables = morison.reportTables(results);

    output_fpath = get_output_fpath();
    excel_writer(reportedTables, output_fpath);

    disp(reportedTables.attachment_calculation);
    disp(reportedTables.summary);
end

function output_fpath = get_output_fpath()
% Private: only used to name this run's output file. Kept local rather
% than its own file, since it's a trivial filename-building step with
% no callers elsewhere and no independent test.

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    output_fname = sprintf('Morison_Results_%s.xlsx', timestamp);
    output_fpath = fullfile(pwd, output_fname);
end

function structure = buildStructure(attachmentsTable, marineGrowthTable)
% Private: the only place input table column names are read. Everything
% below this function works with typed objects, not tables.

    attachments = buildAttachments(attachmentsTable);
    growth = buildMarineGrowthProfile(marineGrowthTable);
    structure = morison.Structure(attachments, growth);
end

function attachments = buildAttachments(attachmentsTable)
    attachments = morison.Attachment.empty(1, 0);
    for i = 1:height(attachmentsTable)
        row = attachmentsTable(i, :);
        range = morison.ElevationRange(row.lower_elevation, row.upper_elevation);
        attachments(end + 1) = morison.Attachment( ...
            string(row.attachment_name), range, row.member_outer_diameter, ...
            row.attachment_outer_diameter, row.centre_to_centre_distance, ...
            row.attachment_angle, row.quantity); %#ok<AGROW>
    end
end

function growth = buildMarineGrowthProfile(marineGrowthTable)
    zones = morison.MarineGrowthZone.empty(1, 0);
    for i = 1:height(marineGrowthTable)
        row = marineGrowthTable(i, :);
        range = morison.ElevationRange(row.lower_elevation, row.upper_elevation);
        growthState = morison.MarineGrowth( ...
            row.marine_growth_thickness, row.mp_drag_coeff, row.mp_inertia_coeff);
        zones(end + 1) = morison.MarineGrowthZone(range, growthState); %#ok<AGROW>
    end
    growth = morison.MarineGrowthProfile(zones);
end
