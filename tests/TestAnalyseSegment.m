classdef TestAnalyseSegment < matlab.unittest.TestCase
% Verifies analyseSegment's own responsibility: summing/maximising
% attachment contributions over heading and combining them with the
% segment's own (already-resolved) marine growth properties via the
% separately-tested IEC equations and calculate_equivalent_hydro_properties.
% Replaces TestCalculateRowIecCdCm and TestCalculateRowEquivalentHydroProperties,
% neither of which needs a table fixture any more.

    methods (Test)
        function combines_attachment_with_segment_growth(test_case)
            range = morison.ElevationRange(0, 10);
            growth = morison.MarineGrowth(0.05, 1, 2);
            attachment = morison.Attachment('Fender', range, 5, 0.5, 4.3, 0, 1);
            segment = morison.HydrodynamicSegment(range, growth, attachment);
            settings = morison.AnalysisSettings(4, 1);

            result = morison.analyseSegment(segment, settings);

            angles = settings.waveAngles();
            cds = arrayfun(@(a) calculate_equivalent_cd(5, 0.5, 4.3, a, 1, 0.05, 1), angles);
            cms = arrayfun(@(a) calculate_equivalent_cm(5, 0.5, 4.3, a, 2, 0.05, 1), angles);

            test_case.verifyEqual(result.EquivalentCd, max(cds), 'AbsTol', 1e-12);
            test_case.verifyEqual(result.EquivalentCm, max(cms), 'AbsTol', 1e-12);

            [expected_thickness, expected_cd_d] = calculate_equivalent_hydro_properties( ...
                5, 0.05, 2, 1, result.EquivalentCm, result.EquivalentCd);
            test_case.verifyEqual(result.AdditionalThickness, expected_thickness);
            test_case.verifyEqual(result.CdD, expected_cd_d);
        end

        function weights_contributions_by_quantity(test_case)
            range = morison.ElevationRange(0, 10);
            growth = morison.MarineGrowth(0.05, 1, 2);
            attachment = morison.Attachment('Fender', range, 5, 0.5, 4.3, 0, 3);
            segment = morison.HydrodynamicSegment(range, growth, attachment);
            settings = morison.AnalysisSettings(1, 1);

            result = morison.analyseSegment(segment, settings);

            single_cd = calculate_equivalent_cd(5, 0.5, 4.3, 0, 1, 0.05, 1);
            single_cm = calculate_equivalent_cm(5, 0.5, 4.3, 0, 2, 0.05, 1);

            test_case.verifyEqual(result.EquivalentCd, 3 * single_cd, 'AbsTol', 1e-12);
            test_case.verifyEqual(result.EquivalentCm, 3 * single_cm, 'AbsTol', 1e-12);
        end

        function sums_multiple_attachments_in_the_same_segment(test_case)
            range = morison.ElevationRange(0, 10);
            growth = morison.MarineGrowth(0.05, 1, 2);
            attachment_a = morison.Attachment('A', range, 5, 0.5, 4.3, 0, 1);
            attachment_b = morison.Attachment('B', range, 5, 0.4, 4.0, 0, 1);
            segment = morison.HydrodynamicSegment(range, growth, [attachment_a, attachment_b]);
            settings = morison.AnalysisSettings(1, 1);

            result = morison.analyseSegment(segment, settings);

            expected_cd = calculate_equivalent_cd(5, 0.5, 4.3, 0, 1, 0.05, 1) + ...
                calculate_equivalent_cd(5, 0.4, 4.0, 0, 1, 0.05, 1);

            test_case.verifyEqual(result.EquivalentCd, expected_cd, 'AbsTol', 1e-12);
            test_case.verifyEqual(numel(result.Contributions), 2);
        end
    end
end
