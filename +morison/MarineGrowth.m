classdef MarineGrowth
% MARINEGROWTH The marine growth STATE at a point on the structure:
% growth thickness, and the member's own drag/inertia coefficients in
% their grown state.
%
%   obj = MarineGrowth(thickness, memberDragCoefficient, memberInertiaCoefficient)
%
%   Deliberately holds no elevation (see MarineGrowthZone, which pairs
%   this with an ElevationRange) and no geometry (member outer diameter
%   lives on Attachment - see its property comment for why). This class
%   describes only what the growth conditions are, never where they
%   apply or what diameter they apply to. Keeping elevation and
%   geometry off this class is what allows a resolved MarineGrowth
%   value to be shared by a HydrodynamicSegment and every Attachment in
%   it without duplicating anything: there is nothing here left to
%   duplicate.
%
%   MemberDragCoefficient and MemberInertiaCoefficient are genuinely
%   growth-determined, not just geometry: drag coefficient in
%   particular is a function of relative surface roughness, so the
%   member's nominal Cd/Cm depend on the growth state they are
%   evaluated in.

    properties (SetAccess = immutable)
        Thickness                (1,1) double = 0
        MemberDragCoefficient    (1,1) double = 0
        MemberInertiaCoefficient (1,1) double = 0
    end

    methods
        function obj = MarineGrowth(thickness, memberDragCoefficient, memberInertiaCoefficient)
            if nargin == 0
                return
            end
            obj.Thickness = thickness;
            obj.MemberDragCoefficient = memberDragCoefficient;
            obj.MemberInertiaCoefficient = memberInertiaCoefficient;
        end
    end
end
