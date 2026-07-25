classdef ElevationRange
% ELEVATIONRANGE An immutable elevation band [Lower, Upper], with the
% comparison tolerance used throughout the toolbox defined in exactly
% one place (Tolerance) rather than scattered across call sites.
%
%   obj = ElevationRange(lower, upper)
%
%   Errors unless upper > lower + Tolerance, so an inverted or
%   degenerate range cannot be constructed (replaces
%   check_elevations_are_ordered).

    properties (SetAccess = immutable)
        Lower (1,1) double = 0
        Upper (1,1) double = 0
    end

    properties (Constant)
        Tolerance = 1e-9
    end

    methods
        function obj = ElevationRange(lower, upper)
            if nargin == 0
                return
            end
            if upper - lower <= ElevationRange.Tolerance
                error('ElevationRange:invalidBounds', ...
                    'Upper elevation (%.6g) must be greater than lower elevation (%.6g).', ...
                    upper, lower);
            end
            obj.Lower = lower;
            obj.Upper = upper;
        end

        function m = midpoint(obj)
            m = (obj.Lower + obj.Upper) / 2;
        end

        function h = height(obj)
            h = obj.Upper - obj.Lower;
        end

        function tf = contains(obj, elevation)
        % CONTAINS True if elevation lies within [Lower, Upper],
        % inclusive of both bounds to within Tolerance.
            tol = ElevationRange.Tolerance;
            tf = (elevation - obj.Lower >= -tol) && (obj.Upper - elevation >= -tol);
        end

        function tf = spans(obj, other)
        % SPANS True if OTHER lies wholly within OBJ, to within
        % Tolerance. Used to test whether an attachment covers a
        % hydrodynamic segment's full height.
            tol = ElevationRange.Tolerance;
            tf = (other.Lower - obj.Lower >= -tol) && (obj.Upper - other.Upper >= -tol);
        end

        function tf = overlaps(obj, other)
        % OVERLAPS True if OBJ and OTHER share more than a single
        % boundary point, i.e. merely-adjacent ranges do not overlap.
            tol = ElevationRange.Tolerance;
            tf = (other.Upper - obj.Lower > tol) && (obj.Upper - other.Lower > tol);
        end

        function r = intersect(obj, other)
            if ~obj.overlaps(other)
                error('ElevationRange:noOverlap', ...
                    'Ranges [%.6g, %.6g] and [%.6g, %.6g] do not overlap.', ...
                    obj.Lower, obj.Upper, other.Lower, other.Upper);
            end
            r = ElevationRange(max(obj.Lower, other.Lower), min(obj.Upper, other.Upper));
        end
    end

    methods (Static)
        function ranges = fromBoundaries(boundaries)
        % FROMBOUNDARIES Sort and deduplicate (to within Tolerance) a
        % set of boundary elevations, then return one ElevationRange per
        % consecutive pair of edges. This is the common refinement used
        % by Structure.hydrodynamicSegments to partition a member at
        % every marine growth AND attachment boundary at once.
            edges = uniquetol(sort(boundaries(:)), ElevationRange.Tolerance, 'DataScale', 1);

            ranges = morison.ElevationRange.empty(1, 0);
            for i = 1:numel(edges) - 1
                ranges(end + 1) = morison.ElevationRange(edges(i), edges(i + 1)); %#ok<AGROW>
            end
        end
    end
end
