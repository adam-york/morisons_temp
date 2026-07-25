classdef TestHydrodynamicSegmentRefinement < matlab.unittest.TestCase
% Verifies Structure.hydrodynamicSegments: partitioning the member at
% every marine growth AND attachment boundary. Replaces
% TestSplitAttachmentsByMarineGrowth, and covers the overlapping-
% attachments defect that the old split-then-groupsummary pipeline had
% (see the second test below), plus the new empty-segment and
% member-outer-diameter-agreement invariants.

    methods (Test)
        function splits_attachment_spanning_two_marine_growth_zones(test_case)
            attachment = morison.Attachment('Fender', ...
                morison.ElevationRange(-5, 15), 5, 0.5, 4.3, 0, 1);

            growth = morison.MarineGrowthProfile([ ...
                morison.MarineGrowthZone(morison.ElevationRange(-10, 10), morison.MarineGrowth(0.05, 1, 2)), ...
                morison.MarineGrowthZone(morison.ElevationRange(10, 20), morison.MarineGrowth(0.10, 0.8, 1.5))]);

            structure = morison.Structure(attachment, growth);
            segments = structure.hydrodynamicSegments();

            test_case.verifyEqual(numel(segments), 2);
            test_case.verifyEqual([segments(1).Range.Lower, segments(1).Range.Upper], [-5, 10]);
            test_case.verifyEqual([segments(2).Range.Lower, segments(2).Range.Upper], [10, 15]);
        end

        function overlapping_attachments_produce_a_shared_segment_with_both(test_case)
            % Regression: the pre-refactor pipeline clipped each
            % attachment to marine growth zones only, then grouped
            % output rows by (lower_elevation, upper_elevation). Two
            % attachments overlapping WITHIN one zone (A: 0-10, B: 5-15)
            % were never split against each other, so the summary
            % produced two overlapping rows and no row that summed both
            % over their shared region (5-10). Refining at attachment
            % boundaries too makes that unrepresentable: the shared
            % region becomes its own segment containing both.
            attachment_a = morison.Attachment('A', morison.ElevationRange(0, 10), 5, 0.5, 4.3, 0, 1);
            attachment_b = morison.Attachment('B', morison.ElevationRange(5, 15), 5, 0.4, 4.0, 0, 1);

            growth = morison.MarineGrowthProfile( ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 20), morison.MarineGrowth(0.05, 1, 2)));

            structure = morison.Structure([attachment_a, attachment_b], growth);
            segments = structure.hydrodynamicSegments();

            test_case.verifyEqual(numel(segments), 3);
            test_case.verifyEqual([segments(1).Range.Lower, segments(1).Range.Upper], [0, 5]);
            test_case.verifyEqual([segments(2).Range.Lower, segments(2).Range.Upper], [5, 10]);
            test_case.verifyEqual([segments(3).Range.Lower, segments(3).Range.Upper], [10, 15]);

            test_case.verifyEqual(numel(segments(1).Attachments), 1);
            test_case.verifyEqual(segments(1).Attachments(1).Name, "A");

            test_case.verifyEqual(numel(segments(2).Attachments), 2);
            names = [segments(2).Attachments.Name];
            test_case.verifyTrue(all(ismember(["A", "B"], names)));

            test_case.verifyEqual(numel(segments(3).Attachments), 1);
            test_case.verifyEqual(segments(3).Attachments(1).Name, "B");
        end

        function segments_with_no_attachments_are_excluded(test_case)
            attachment_a = morison.Attachment('A', morison.ElevationRange(0, 5), 5, 0.5, 4.3, 0, 1);
            attachment_b = morison.Attachment('B', morison.ElevationRange(10, 15), 5, 0.5, 4.3, 0, 1);

            growth = morison.MarineGrowthProfile( ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 15), morison.MarineGrowth(0.05, 1, 2)));

            structure = morison.Structure([attachment_a, attachment_b], growth);
            segments = structure.hydrodynamicSegments();

            test_case.verifyEqual(numel(segments), 2);
            test_case.verifyEqual([segments(1).Range.Lower, segments(1).Range.Upper], [0, 5]);
            test_case.verifyEqual([segments(2).Range.Lower, segments(2).Range.Upper], [10, 15]);
        end

        function keeps_attachment_geometry_and_does_not_merge_marine_growth(test_case)
            attachment = morison.Attachment('Ladder', morison.ElevationRange(0, 5), 5, 0.3, 4.0, 0, 3);
            growth = morison.MarineGrowthProfile( ...
                morison.MarineGrowthZone(morison.ElevationRange(-10, 20), morison.MarineGrowth(0.05, 1, 2)));

            structure = morison.Structure(attachment, growth);
            segments = structure.hydrodynamicSegments();

            test_case.verifyEqual(segments(1).Attachments(1).Quantity, 3);
            test_case.verifyEqual(segments(1).Growth.Thickness, 0.05);
        end

        function disagreeing_member_outer_diameter_errors(test_case)
            attachment_a = morison.Attachment('A', morison.ElevationRange(0, 10), 5, 0.5, 4.3, 0, 1);
            attachment_b = morison.Attachment('B', morison.ElevationRange(0, 10), 6, 0.4, 4.0, 0, 1);

            growth = morison.MarineGrowthProfile( ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 10), morison.MarineGrowth(0.05, 1, 2)));

            structure = morison.Structure([attachment_a, attachment_b], growth);
            test_case.verifyError(@() structure.hydrodynamicSegments(), ...
                'HydrodynamicSegment:memberOuterDiameterDisagreement');
        end
    end
end
