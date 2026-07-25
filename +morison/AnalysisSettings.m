classdef AnalysisSettings
% ANALYSISSETTINGS Analysis parameters that were previously magic
% numbers scattered through the pipeline: n_wave_dirs = 24 in the old
% process.m, and wave_spreading_factor = 1 buried three levels down in
% calculate_row_iec_cd_cm. Named, defaulted, and overridable.
%
%   obj = AnalysisSettings()                                  % defaults
%   obj = AnalysisSettings(waveDirectionCount, waveSpreadingFactor)

    properties (SetAccess = immutable)
        WaveDirectionCount  (1,1) double {mustBePositive, mustBeInteger} = 24
        WaveSpreadingFactor (1,1) double = 1
    end

    methods
        function obj = AnalysisSettings(waveDirectionCount, waveSpreadingFactor)
            if nargin == 0
                return
            end
            obj.WaveDirectionCount = waveDirectionCount;
            obj.WaveSpreadingFactor = waveSpreadingFactor;
        end

        function angles = waveAngles(obj)
        % WAVEANGLES WaveDirectionCount evenly spaced headings (deg),
        % starting at 0: 0, 360/n, 2*360/n, ..., (n-1)*360/n.
            stepIndices = (0:obj.WaveDirectionCount - 1)';
            angles = stepIndices * 360 / obj.WaveDirectionCount;
        end
    end
end
