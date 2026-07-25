classdef AttachmentContribution
% ATTACHMENTCONTRIBUTION One attachment's quantity-weighted Cd/Cm
% contribution at one wave heading.
%
%   obj = AttachmentContribution(attachmentName, waveAngle, cd, cm)
%
%   Retained on SegmentResult for reporting only (the
%   "attachment_calculation" sheet) - nothing calculates from it.

    properties (SetAccess = immutable)
        AttachmentName (1,1) string = ""
        WaveAngle      (1,1) double = 0
        Cd             (1,1) double = 0
        Cm             (1,1) double = 0
    end

    methods
        function obj = AttachmentContribution(attachmentName, waveAngle, cd, cm)
            if nargin == 0
                return
            end
            obj.AttachmentName = attachmentName;
            obj.WaveAngle = waveAngle;
            obj.Cd = cd;
            obj.Cm = cm;
        end
    end
end
