classdef HydrodynamicSegment
% HYDRODYNAMICSEGMENT A region of the member with uniform hydrodynamic
% conditions: exactly one set of marine growth properties (Growth), and
% a fixed, non-empty set of Attachments that are each present over the
% segment's full height.
%
%   obj = HydrodynamicSegment(range, growth, attachments)
%
%   This is the type that makes "marine growth properties vary within
%   an attachment calculation row" unrepresentable: Growth is (1,1),
%   not a lookup, so it is not possible to construct a segment with two
%   sets of marine growth properties, or with none. The constructor
%   also checks that every attachment fully spans Range, and that all
%   attachments agree on MemberOuterDiameter, deriving a single agreed
%   value that every downstream consumer can use without needing to
%   know it originated on the attachments.
%
%   Construction is deliberately left public rather than restricted to
%   Structure: the invariants are enforced by the constructor itself,
%   so a self-validating public constructor is safe regardless of
%   caller, and remains directly testable.

    properties (SetAccess = immutable)
        Range               (1,1) morison.ElevationRange
        Growth              (1,1) morison.MarineGrowth
        Attachments         (1,:) morison.Attachment
        MemberOuterDiameter (1,1) double = 0
    end

    methods
        function obj = HydrodynamicSegment(range, growth, attachments)
            if nargin == 0
                return
            end
            if isempty(attachments)
                error('HydrodynamicSegment:noAttachments', ...
                    'A hydrodynamic segment must have at least one attachment.');
            end
            checkAttachmentsSpanRange(attachments, range);

            obj.Range = range;
            obj.Growth = growth;
            obj.Attachments = attachments;
            obj.MemberOuterDiameter = resolveMemberOuterDiameter(attachments);
        end
    end
end

function checkAttachmentsSpanRange(attachments, range)
    for i = 1:numel(attachments)
        if ~attachments(i).Range.spans(range)
            error('HydrodynamicSegment:attachmentDoesNotSpanRange', ...
                'Attachment "%s" (range [%.6g, %.6g]) does not fully span segment range [%.6g, %.6g].', ...
                attachments(i).Name, attachments(i).Range.Lower, attachments(i).Range.Upper, ...
                range.Lower, range.Upper);
        end
    end
end

function memberOuterDiameter = resolveMemberOuterDiameter(attachments)
    tol = morison.ElevationRange.Tolerance;
    memberOuterDiameter = attachments(1).MemberOuterDiameter;
    for i = 2:numel(attachments)
        if abs(attachments(i).MemberOuterDiameter - memberOuterDiameter) > tol
            error('HydrodynamicSegment:memberOuterDiameterDisagreement', ...
                ['Attachments "%s" and "%s" disagree on member outer diameter ' ...
                 '(%.6g vs %.6g) over the same segment.'], ...
                attachments(1).Name, attachments(i).Name, ...
                memberOuterDiameter, attachments(i).MemberOuterDiameter);
        end
    end
end
