function result = analyseSegment(segment, settings)
% ANALYSESEGMENT Pure calculation of the equivalent Cd/Cm and equivalent
% additional thickness/Cd*D for one HydrodynamicSegment.
%
%   result = analyseSegment(segment, settings)
%
%   Pure: SegmentResult is a total function of (segment, settings). No
%   elevation lookups, no ambient state, no dependency on any other
%   segment or on evaluation order - unlike the old
%   calculate_row_iec_cd_cm / calculate_row_equivalent_hydro_properties,
%   segment.Growth and segment.MemberOuterDiameter are already resolved
%   values, not table lookups performed here.

    angles = settings.waveAngles();
    contributions = attachmentContributions(segment, angles, settings);
    [equivalentCd, equivalentCm] = worstCaseOverHeading(contributions, angles);

    [additionalThickness, cdD] = calculate_equivalent_hydro_properties( ...
        segment.MemberOuterDiameter, segment.Growth.Thickness, ...
        segment.Growth.MemberInertiaCoefficient, segment.Growth.MemberDragCoefficient, ...
        equivalentCm, equivalentCd);

    result = morison.SegmentResult(segment.Range, equivalentCd, equivalentCm, ...
        additionalThickness, cdD, contributions);
end

function contributions = attachmentContributions(segment, angles, settings)
% One AttachmentContribution per (attachment, wave angle) pair. Cd/Cm
% are quantity-weighted here, so a row representing N identical
% attachments contributes N times its per-attachment value.

    contributions = morison.AttachmentContribution.empty(1, 0);

    for attachmentIndex = 1:numel(segment.Attachments)
        attachment = segment.Attachments(attachmentIndex);

        for angleIndex = 1:numel(angles)
            waveAngle = angles(angleIndex);
            relativeAngle = attachment.relativeWaveAngle(waveAngle);

            cd = calculate_equivalent_cd( ...
                segment.MemberOuterDiameter, attachment.OuterDiameter, ...
                attachment.CentreToCentreDistance, relativeAngle, ...
                segment.Growth.MemberDragCoefficient, segment.Growth.Thickness, ...
                settings.WaveSpreadingFactor) * attachment.Quantity;

            cm = calculate_equivalent_cm( ...
                segment.MemberOuterDiameter, attachment.OuterDiameter, ...
                attachment.CentreToCentreDistance, relativeAngle, ...
                segment.Growth.MemberInertiaCoefficient, segment.Growth.Thickness, ...
                settings.WaveSpreadingFactor) * attachment.Quantity;

            contributions(end + 1) = morison.AttachmentContribution( ...
                attachment.Name, waveAngle, cd, cm); %#ok<AGROW>
        end
    end
end

function [cd, cm] = worstCaseOverHeading(contributions, angles)
% Sum each heading's attachment contributions, then take the largest Cd
% and the largest Cm across headings.
%
% NOTE: the maxima are taken INDEPENDENTLY. The returned Cd and Cm may
% come from two different wave headings and need not correspond to any
% single physical sea state. This is intentional: drag and inertia peak
% at different headings, and the design case must envelope both.
% Pairing them to a common heading would be non-conservative. Do not
% "fix" this by selecting the heading that maximises Cd and reading Cm
% from that same heading.

    contributionAngles = [contributions.WaveAngle];
    cdPerAngle = arrayfun(@(a) sum([contributions(contributionAngles == a).Cd]), angles);
    cmPerAngle = arrayfun(@(a) sum([contributions(contributionAngles == a).Cm]), angles);

    cd = max(cdPerAngle);
    cm = max(cmPerAngle);
end
