classdef TestElevationRange < matlab.unittest.TestCase
% Range algebra: pure, exhaustive, no fixtures. Replaces
% TestCalculateMidpointElevation and the containment logic previously
% spread across TestFindElevationRowIndex / TestGetValueByElevation.

    methods (Test)
        function midpoint_returns_average_of_bounds(test_case)
            r = morison.ElevationRange(2, 8);
            test_case.verifyEqual(r.midpoint(), 5);
        end

        function height_returns_difference_of_bounds(test_case)
            r = morison.ElevationRange(2, 8);
            test_case.verifyEqual(r.height(), 6);
        end

        function constructor_errors_when_upper_not_greater_than_lower(test_case)
            test_case.verifyError(@() morison.ElevationRange(10, 10), 'ElevationRange:invalidBounds');
            test_case.verifyError(@() morison.ElevationRange(10, 5), 'ElevationRange:invalidBounds');
        end

        function contains_is_inclusive_of_bounds(test_case)
            r = morison.ElevationRange(0, 10);
            test_case.verifyTrue(r.contains(0));
            test_case.verifyTrue(r.contains(10));
            test_case.verifyTrue(r.contains(5));
            test_case.verifyFalse(r.contains(10.1));
        end

        function spans_is_true_only_when_other_lies_wholly_within(test_case)
            outer = morison.ElevationRange(0, 20);
            inner = morison.ElevationRange(5, 15);
            straddling = morison.ElevationRange(-5, 15);

            test_case.verifyTrue(outer.spans(inner));
            test_case.verifyFalse(outer.spans(straddling));
            test_case.verifyTrue(outer.spans(outer));
        end

        function overlaps_is_false_for_merely_adjacent_ranges(test_case)
            a = morison.ElevationRange(0, 10);
            b = morison.ElevationRange(10, 20);
            c = morison.ElevationRange(5, 15);

            test_case.verifyFalse(a.overlaps(b));
            test_case.verifyTrue(a.overlaps(c));
        end

        function from_boundaries_builds_consecutive_ranges(test_case)
            ranges = morison.ElevationRange.fromBoundaries([10, 0, 5]);

            test_case.verifyEqual(numel(ranges), 2);
            test_case.verifyEqual([ranges(1).Lower, ranges(1).Upper], [0, 5]);
            test_case.verifyEqual([ranges(2).Lower, ranges(2).Upper], [5, 10]);
        end

        function from_boundaries_deduplicates_near_identical_edges(test_case)
            ranges = morison.ElevationRange.fromBoundaries([0, 5, 5 + 1e-12, 10]);
            test_case.verifyEqual(numel(ranges), 2);
        end
    end
end
