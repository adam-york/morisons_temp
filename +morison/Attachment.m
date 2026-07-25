classdef Attachment
% ATTACHMENT An attachment mounted on the structure's member over a
% fixed elevation range - equivalent to one row of the attachment input
% table.
%
%   obj = Attachment(name, range, memberOuterDiameter, outerDiameter, ...
%             centreToCentreDistance, angle, quantity)
%
%   Holds no marine growth data, and no elevation numbers outside
%   Range. Marine growth is resolved onto a HydrodynamicSegment, never
%   onto an Attachment - see HydrodynamicSegment.

    properties (SetAccess = immutable)
        Name (1,1) string = ""
        Range (1,1) morison.ElevationRange

        % MemberOuterDiameter: the clean-steel outer diameter of the
        % MEMBER this attachment is mounted on (not the attachment's
        % own diameter - see OuterDiameter below). This lives on
        % Attachment rather than on MarineGrowth/MarineGrowthZone
        % because it is fixed structural geometry, not a growth
        % property: it does not vary with marine growth banding, and
        % grouping it with CentreToCentreDistance keeps both of the
        % attachment's "relationship to the member" measurements
        % together, ready for the IEC equations that consume both.
        MemberOuterDiameter (1,1) double = 0

        OuterDiameter          (1,1) double = 0
        CentreToCentreDistance (1,1) double = 0
        Angle                  (1,1) double = 0
        Quantity                (1,1) double = 0
    end

    methods
        function obj = Attachment(name, range, memberOuterDiameter, outerDiameter, ...
                centreToCentreDistance, angle, quantity)
            if nargin == 0
                return
            end
            obj.Name = name;
            obj.Range = range;
            obj.MemberOuterDiameter = memberOuterDiameter;
            obj.OuterDiameter = outerDiameter;
            obj.CentreToCentreDistance = centreToCentreDistance;
            obj.Angle = angle;
            obj.Quantity = quantity;
        end

        function relativeAngle = relativeWaveAngle(obj, waveAngle)
        % RELATIVEWAVEANGLE The wave heading relative to this
        % attachment's own orientation, wrapped into [0, 360) deg.
            relativeAngle = mod(waveAngle - obj.Angle, 360);
        end
    end
end
