function excel_writer(tables_to_export, output_file_path)
% EXCEL_WRITER Export any number of tables to an Excel file, one tab
% per table.
%
%   Inputs:
%       tables_to_export   struct where each field is a table. The
%                           field name is used as the sheet name.
%       output_file_path   path to the .xlsx file to create

    validate_tables_struct(tables_to_export);

    sheet_names = fieldnames(tables_to_export);
    for sheet_index = 1:numel(sheet_names)
        sheet_name = sheet_names{sheet_index};
        write_table_to_sheet(tables_to_export.(sheet_name), output_file_path, sheet_name);
    end
end

function write_table_to_sheet(data_table, output_file_path, sheet_name)
% Write data_table to a named sheet, with headers matching column names.

    writetable(data_table, output_file_path, ...
        'Sheet', sheet_name, ...
        'WriteVariableNames', true);
end

function validate_tables_struct(tables_to_export)
% Private: only used to check excel_writer's own input shape. Kept
% local rather than its own file, since it's specific to this
% function's contract, with no callers elsewhere and no independent
% test.

    if ~isstruct(tables_to_export) || ~isscalar(tables_to_export)
        error('excel_writer:invalid_input', ...
            'tables_to_export must be a scalar struct with one table per field.');
    end

    field_names = fieldnames(tables_to_export);
    for field_index = 1:numel(field_names)
        if ~istable(tables_to_export.(field_names{field_index}))
            error('excel_writer:invalid_field', ...
                'Field "%s" must contain a table.', field_names{field_index});
        end
    end
end
