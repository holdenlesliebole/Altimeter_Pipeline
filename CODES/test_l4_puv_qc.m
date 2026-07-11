function test_l4_puv_qc()
%TEST_L4_PUV_QC  Unit test for the L4 PUV QC-provenance helper (backward compatibility +
% the channel-decoupling flags).
%
% Run:  >> test_l4_puv_qc
%
% 2026-07-10.
fprintf('\n=== test_l4_puv_qc ===\n');
ok = true;

% Case OLD-valid: a pre-decoupling L2 (only segValid). A valid segment must read as good and
% contribute -- this is what reproduces the historical L4.
Lold = struct('segValid', [true; false; true]);
q = l4_puv_qc(Lold, 1);
ok = rep('OLD valid  -> qc_flag 1, use true', q.qc_flag==1 && q.use && q.segValid_vel && q.segValid_p, q.qc_flag) && ok;
q = l4_puv_qc(Lold, 2);
ok = rep('OLD invalid -> qc_flag 2, still use (not a FAIL)', q.qc_flag==2 && q.use, q.qc_flag) && ok;

% Case NEW-clean: qc_flag 1, both channels valid.
Lnew = struct('qc_flag',[1;3;4], 'segValid_vel',[true;true;false], 'segValid_p',[true;false;false], ...
              'segValid',[true;false;false]);
q = l4_puv_qc(Lnew, 1);
ok = rep('NEW clean  -> qc 1, use, both channels', q.qc_flag==1 && q.use && q.segValid_vel && q.segValid_p, q.qc_flag) && ok;

% Case NEW-recovered: qc_flag 3 (velocity moments recovered, pressure dead). MUST still
% contribute (that is the recovery) but be flagged, and segValid_p false.
q = l4_puv_qc(Lnew, 2);
ok = rep('NEW recovered -> qc 3, USE true, vel valid, p invalid', ...
    q.qc_flag==3 && q.use && q.segValid_vel && ~q.segValid_p, q.qc_flag) && ok;

% Case NEW-fail: qc_flag 4. MUST NOT contribute.
q = l4_puv_qc(Lnew, 3);
ok = rep('NEW fail   -> qc 4, use FALSE (dropped from L4)', q.qc_flag==4 && ~q.use, q.qc_flag) && ok;

fprintf('\n%s\n', repmat('-',1,54));
if ok, fprintf('ALL PASS\n'); else, error('test_l4_puv_qc:FAIL','assertion failed'); end
end

function ok = rep(name, cond, val)
ok = logical(cond);
if ok, s='PASS'; else, s='FAIL'; end
fprintf('  [%s] %-46s %g\n', s, name, double(val));
end
