function q = l4_puv_qc(L2, s)
%L4_PUV_QC  Per-segment PUV QC provenance for the L4 build (channel decoupling).
%
%   q = l4_puv_qc(L2, s)   returns the QC status of segment s of an L2 struct:
%     q.qc_flag        QARTOD flag (1 good, 2 not evaluated, 3 suspect, 4 fail)
%     q.segValid_vel   velocity products usable
%     q.segValid_p     pressure products (Hs, depth) usable
%     q.use            whether this segment may contribute to L4 at all (qc_flag ~= 4)
%
% BACKWARD COMPATIBLE. L2 files written before the channel-decoupling change have none of
% these fields; they are treated as fully good (qc_flag = 1, both channels valid where
% segValid is true), so build_L4_site reproduces the historical L4 on old data exactly.
%
% The point: after the rerun, L2 carries velocity-only (qc_flag = 3, Hs NaN) and
% implausible-pressure (qc_flag = 4) segments. build_L4_site.getL2/getL2sub pull fields by
% index with no filter, so without this a FAIL segment would leak into clean L4 fields and a
% recovered (suspect) moment would be indistinguishable from a clean one. This makes the
% provenance explicit and drops FAIL segments.
%
% 2026-07-10.

if isfield(L2, 'qc_flag')
    q.qc_flag = L2.qc_flag(s);
else
    % Old L2: infer from segValid. A valid segment is good (1); an invalid one was NaN'd
    % across the board by the old row-level gate, so it is "not evaluated" (2), not a fail.
    if isfield(L2,'segValid') && L2.segValid(s), q.qc_flag = 1; else, q.qc_flag = 2; end
end

if isfield(L2, 'segValid_vel'), q.segValid_vel = logical(L2.segValid_vel(s));
elseif isfield(L2,'segValid'),  q.segValid_vel = logical(L2.segValid(s));
else,                           q.segValid_vel = true; end

if isfield(L2, 'segValid_p'), q.segValid_p = logical(L2.segValid_p(s));
elseif isfield(L2,'segValid'),q.segValid_p = logical(L2.segValid(s));
else,                         q.segValid_p = true; end

q.use = q.qc_flag ~= 4;   % a FAIL segment contributes nothing to any L4 field
end
