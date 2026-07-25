classdef Structure
% STRUCTURE The composition root: the full set of Attachments together
% with the MarineGrowthProfile that applies to the member they are
% mounted on.
%
%   obj = Structure(attachments, growth)
%
%   This is the ONLY place the attachment<->marine-growth association
%   is ever resolved (see hydrodynamicSegments). Neither Attachment nor
%   MarineGrowth/MarineGrowthProfile knows about the other; they meet
%   only inside a HydrodynamicSegment, created here.

    properties (SetAccess = immutable)
        Attachments (1,:) morison.Attachment
        Growth      (1,1) morison.MarineGrowthProfile
    end

    methods
        function obj = Structure(attachments, growth)
            if nargin == 0
                return
            end
            checkGrowthCoversAttachments(attachments, growth);
            obj.Attachments = attachments;
            obj.Growth = growth;
        end

        function segments = hydrodynamicSegments(obj)
        % HYDRODYNAMICSEGMENTS Partition the member at every marine
        % growth AND attachment boundary.
        %
        %   Because the refinement includes every marine growth zone
        %   boundary, no candidate range can straddle a zone - so
        %   looking up growth at each range's midpoint (below) is safe,
        %   guaranteed by the three lines that built the ranges rather
        %   than by a step that ran earlier and left no trace.
        %
        %   Because the refinement also includes every attachment
        %   boundary, an attachment either covers a candidate range
        %   completely or misses it completely: partial overlap is
        %   arithmetically impossible, which is what resolves the
        %   overlapping-attachments defect in the previous
        %   implementation (two attachments overlapping within one
        %   marine growth zone now share a segment over their common
        %   region, instead of producing two overlapping output rows
        %   that never sum them).
        %
        %   Ranges with no attachments are dropped here, at the point
        %   of creation, rather than filtered later during reporting:
        %   such a range has no member outer diameter to report (see
        %   HydrodynamicSegment), so it is not merely uninteresting, it
        %   is unconstructible.
            ranges = morison.ElevationRange.fromBoundaries(allBoundaries(obj));

            segments = morison.HydrodynamicSegment.empty(1, 0);
            for i = 1:numel(ranges)
                presentAttachments = attachmentsSpanning(obj.Attachments, ranges(i));
                if isempty(presentAttachments)
                    continue
                end
                growth = obj.Growth.at(ranges(i).midpoint());
                segments(end + 1) = morison.HydrodynamicSegment( ...
                    ranges(i), growth, presentAttachments); %#ok<AGROW>
            end
        end
    end
end

function checkGrowthCoversAttachments(attachments, growth)
    tol = morison.ElevationRange.Tolerance;
    profileSpan = growth.span();
    attachmentLowers = arrayfun(@(a) a.Range.Lower, attachments);
    attachmentUppers = arrayfun(@(a) a.Range.Upper, attachments);

    if profileSpan.Lower - min(attachmentLowers) > tol
        error('Structure:marineGrowthDoesNotCoverLowerRange', ...
            'Marine growth definition does not extend down to the lowest attachment elevation (%.6g).', ...
            min(attachmentLowers));
    end
    if max(attachmentUppers) - profileSpan.Upper > tol
        error('Structure:marineGrowthDoesNotCoverUpperRange', ...
            'Marine growth definition does not extend up to the highest attachment elevation (%.6g).', ...
            max(attachmentUppers));
    end
end

function edges = allBoundaries(obj)
    profileSpan = obj.Growth.span();

    growthEdges = obj.Growth.boundaries();
    attachmentLowers = arrayfun(@(a) a.Range.Lower, obj.Attachments);
    attachmentUppers = arrayfun(@(a) a.Range.Upper, obj.Attachments);

    candidateEdges = [growthEdges, attachmentLowers, attachmentUppers];
    tol = morison.ElevationRange.Tolerance;
    inRange = candidateEdges >= profileSpan.Lower - tol & candidateEdges <= profileSpan.Upper + tol;

    edges = uniquetol(sort(candidateEdges(inRange)), tol, 'DataScale', 1);
end

function present = attachmentsSpanning(attachments, range)
    mask = arrayfun(@(a) a.Range.spans(range), attachments);
    present = attachments(mask);
end
