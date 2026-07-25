classdef MarineGrowthZone
% MARINEGROWTHZONE One input band: an ElevationRange paired with the
% MarineGrowth that applies over it - equivalent to one row of the
% marine growth input table.
%
%   obj = MarineGrowthZone(range, growth)
%
%   Named "zone" rather than "segment" deliberately, to keep input
%   bands (this class) visually distinct from the derived
%   HydrodynamicSegment produced by Structure.hydrodynamicSegments.

    properties (SetAccess = immutable)
        Range  (1,1) morison.ElevationRange
        Growth (1,1) morison.MarineGrowth
    end

    methods
        function obj = MarineGrowthZone(range, growth)
            if nargin == 0
                return
            end
            obj.Range = range;
            obj.Growth = growth;
        end
    end
end
