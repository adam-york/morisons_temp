classdef TestMarineGrowthProfile < matlab.unittest.TestCase
% Constructor validation: MarineGrowthProfile absorbs
% check_elevations_are_contiguous and check_elevations_have_no_overlaps
% as invariants enforced once, at construction, rather than as
% free-standing checks called before every calculation. Also covers the
% single elevation lookup left in the system (at), replacing
% TestLookupMarineGrowthProperties / TestGetValueByElevation /
% TestFindElevationRowIndex.

    methods (Test)
        function accepts_contiguous_zones(test_case)
            zones = [ ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 10), morison.MarineGrowth(0.05, 1, 2)), ...
                morison.MarineGrowthZone(morison.ElevationRange(10, 20), morison.MarineGrowth(0.10, 0.8, 1.5))];

            test_case.verifyWarningFree(@() morison.MarineGrowthProfile(zones));
        end

        function errors_when_there_is_a_gap(test_case)
            zones = [ ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 10), morison.MarineGrowth(0.05, 1, 2)), ...
                morison.MarineGrowthZone(morison.ElevationRange(15, 20), morison.MarineGrowth(0.10, 0.8, 1.5))];

            test_case.verifyError(@() morison.MarineGrowthProfile(zones), 'MarineGrowthProfile:gap');
        end

        function errors_when_zones_overlap(test_case)
            zones = [ ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 12), morison.MarineGrowth(0.05, 1, 2)), ...
                morison.MarineGrowthZone(morison.ElevationRange(10, 20), morison.MarineGrowth(0.10, 0.8, 1.5))];

            test_case.verifyError(@() morison.MarineGrowthProfile(zones), 'MarineGrowthProfile:overlap');
        end

        function sorts_zones_regardless_of_input_order(test_case)
            zones = [ ...
                morison.MarineGrowthZone(morison.ElevationRange(10, 20), morison.MarineGrowth(0.10, 0.8, 1.5)), ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 10), morison.MarineGrowth(0.05, 1, 2))];

            profile = morison.MarineGrowthProfile(zones);

            test_case.verifyEqual(profile.Zones(1).Range.Lower, 0);
            test_case.verifyEqual(profile.Zones(2).Range.Lower, 10);
        end

        function at_returns_the_covering_zones_growth(test_case)
            zones = [ ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 10), morison.MarineGrowth(0.05, 1, 2)), ...
                morison.MarineGrowthZone(morison.ElevationRange(10, 20), morison.MarineGrowth(0.10, 0.8, 1.5))];
            profile = morison.MarineGrowthProfile(zones);

            growth = profile.at(15);

            test_case.verifyEqual(growth.Thickness, 0.10);
            test_case.verifyEqual(growth.MemberDragCoefficient, 0.8);
        end

        function at_picks_up_different_zone_for_different_elevation(test_case)
            % Confirms the lookup actually varies with elevation rather
            % than always returning the first zone.
            zones = [ ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 10), morison.MarineGrowth(0.05, 1, 2)), ...
                morison.MarineGrowthZone(morison.ElevationRange(10, 20), morison.MarineGrowth(0.10, 0.8, 1.5))];
            profile = morison.MarineGrowthProfile(zones);

            growth = profile.at(5);

            test_case.verifyEqual(growth.Thickness, 0.05);
            test_case.verifyEqual(growth.MemberDragCoefficient, 1);
        end

        function at_errors_when_elevation_not_covered(test_case)
            profile = morison.MarineGrowthProfile( ...
                morison.MarineGrowthZone(morison.ElevationRange(0, 10), morison.MarineGrowth(0.05, 1, 2)));

            test_case.verifyError(@() profile.at(100), 'MarineGrowthProfile:elevationNotCovered');
        end
    end
end
