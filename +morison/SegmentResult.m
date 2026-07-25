classdef SegmentResult
% SEGMENTRESULT The final, reportable result for one
% HydrodynamicSegment: attachment-only worst-case equivalent Cd/Cm, and
% the resulting equivalent additional thickness / Cd*D for the member
% in that segment.
%
%   obj = SegmentResult(range, equivalentCd, equivalentCm, ...
%             additionalThickness, cdD, contributions)

    properties (SetAccess = immutable)
        Range        (1,1) morison.ElevationRange
        EquivalentCd (1,1) double = 0   % attachments only, worst case over heading

        % EquivalentCm: worst case over heading, taken INDEPENDENTLY of
        % EquivalentCd - see analyseSegment's worstCaseOverHeading for
        % why. The pair need not correspond to the same wave heading.
        EquivalentCm (1,1) double = 0

        AdditionalThickness (1,1) double = 0   % member + attachments combined
        CdD                 (1,1) double = 0
        Contributions       (1,:) morison.AttachmentContribution
    end

    methods
        function obj = SegmentResult(range, equivalentCd, equivalentCm, ...
                additionalThickness, cdD, contributions)
            if nargin == 0
                return
            end
            obj.Range = range;
            obj.EquivalentCd = equivalentCd;
            obj.EquivalentCm = equivalentCm;
            obj.AdditionalThickness = additionalThickness;
            obj.CdD = cdD;
            obj.Contributions = contributions;
        end
    end
end
