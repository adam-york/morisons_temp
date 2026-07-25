classdef TestAttachment < matlab.unittest.TestCase
% Replaces TestCalculateRelativeWaveAngle: the calculation is now a
% method on the object that actually owns Angle.

    methods (Test)
        function relative_wave_angle_wraps_around_360(test_case)
            attachment = morison.Attachment('A', morison.ElevationRange(0, 10), 5, 0.5, 4.3, 350, 1);
            test_case.verifyEqual(attachment.relativeWaveAngle(10), 20);
        end

        function relative_wave_angle_is_zero_when_equal(test_case)
            attachment = morison.Attachment('A', morison.ElevationRange(0, 10), 5, 0.5, 4.3, 90, 1);
            test_case.verifyEqual(attachment.relativeWaveAngle(90), 0);
        end
    end
end
