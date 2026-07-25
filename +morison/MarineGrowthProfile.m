classdef MarineGrowthProfile
% MARINEGROWTHPROFILE An ordered set of contiguous, non-overlapping
% MarineGrowthZones - equivalent to the whole marine growth input
% table.
%
%   obj = MarineGrowthProfile(zones)
%
%   Sorts the zones by elevation and validates contiguity and
%   non-overlap ONCE, in the constructor (absorbing
%   check_elevations_are_contiguous and check_elevations_have_no_overlaps
%   as invariants rather than free-standing pre-flight checks). A
%   MarineGrowthProfile that exists is a valid one.

    properties (SetAccess = immutable)
        Zones (1,:) morison.MarineGrowthZone
    end

    methods
        function obj = MarineGrowthProfile(zones)
            if nargin == 0
                return
            end
            sortedZones = sortZonesByLowerElevation(zones);
            checkContiguous(sortedZones);
            checkNoOverlaps(sortedZones);
            obj.Zones = sortedZones;
        end

        function growth = at(obj, elevation)
        % AT Return the MarineGrowth that applies at elevation. This is
        % the only elevation lookup in the whole system - its single
        % caller is Structure.hydrodynamicSegments, which resolves it
        % once per segment. No other code performs an elevation lookup.
            for i = 1:numel(obj.Zones)
                if obj.Zones(i).Range.contains(elevation)
                    growth = obj.Zones(i).Growth;
                    return
                end
            end
            error('MarineGrowthProfile:elevationNotCovered', ...
                'No marine growth zone covers elevation %.6g.', elevation);
        end

        function r = span(obj)
        % SPAN The ElevationRange covering every zone in the profile.
            r = morison.ElevationRange(obj.Zones(1).Range.Lower, obj.Zones(end).Range.Upper);
        end

        function edges = boundaries(obj)
        % BOUNDARIES Sorted, deduplicated elevations of every zone
        % boundary. Feeds Structure.hydrodynamicSegments' refinement.
            lowers = arrayfun(@(z) z.Range.Lower, obj.Zones);
            uppers = arrayfun(@(z) z.Range.Upper, obj.Zones);
            edges = uniquetol(sort([lowers, uppers]), morison.ElevationRange.Tolerance, 'DataScale', 1);
        end
    end
end

function sortedZones = sortZonesByLowerElevation(zones)
    lowers = arrayfun(@(z) z.Range.Lower, zones);
    [~, order] = sort(lowers);
    sortedZones = zones(order);
end

function checkContiguous(sortedZones)
    tol = morison.ElevationRange.Tolerance;
    for i = 1:numel(sortedZones) - 1
        gap = sortedZones(i + 1).Range.Lower - sortedZones(i).Range.Upper;
        if gap > tol
            error('MarineGrowthProfile:gap', ...
                'Gap of %.6g between marine growth zones ending at %.6g and starting at %.6g.', ...
                gap, sortedZones(i).Range.Upper, sortedZones(i + 1).Range.Lower);
        end
    end
end

function checkNoOverlaps(sortedZones)
    tol = morison.ElevationRange.Tolerance;
    for i = 1:numel(sortedZones) - 1
        overlap = sortedZones(i).Range.Upper - sortedZones(i + 1).Range.Lower;
        if overlap > tol
            error('MarineGrowthProfile:overlap', ...
                'Overlap of %.6g between marine growth zones ending at %.6g and starting at %.6g.', ...
                overlap, sortedZones(i).Range.Upper, sortedZones(i + 1).Range.Lower);
        end
    end
end
