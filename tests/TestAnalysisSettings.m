classdef TestAnalysisSettings < matlab.unittest.TestCase
% Replaces TestCalculateWaveAngles: wave direction count is now a named,
% defaulted, overridable setting instead of a literal in process.m.

    methods (Test)
        function wave_angles_are_evenly_spaced_from_zero(test_case)
            settings = morison.AnalysisSettings(12, 1);
            angles = settings.waveAngles();

            test_case.verifyEqual(angles(1), 0);
            test_case.verifyEqual(angles(2), 30);
            test_case.verifyEqual(angles(end), 330);
            test_case.verifyEqual(numel(angles), 12);
        end

        function defaults_match_the_previous_hard_coded_values(test_case)
            settings = morison.AnalysisSettings();
            test_case.verifyEqual(settings.WaveDirectionCount, 24);
            test_case.verifyEqual(settings.WaveSpreadingFactor, 1);
        end
    end
end
