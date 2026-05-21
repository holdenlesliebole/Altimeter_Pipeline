% Per-raw-file clock map via cross-correlation vs concurrent same-site PUV.
% Reliable (temperature, same quantity); lag at peak r = clock offset.
% offset-to-UTC = -lag (lag +8 => local PST => add 8; lag 0 => UTC => add 0).
addpath('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/CODES');
puvL2='/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs/L2';

altDirs = struct('tag',{'TP','SOL','SIO'}, ...
  'dir',{'/Volumes/group/Altimeter_data/TorreyPines', ...
         '/Volumes/group/Altimeter_data/SolanaBeach', ...
         '/Volumes/group/Altimeter_data/SouthSIOPier/data/AltimeterData'}, ...
  'puv',{{'TBR23','TOR23W','TOR24S','TOR24W','TOR25S'}, {'SOL23','SOL24','SOL25A','SOL25B'}, ...
         {'SIO24A','SIO24B','SIO24C','SIO25A','SIO25B','SIO25C','SIO25D','SIO25E'}});

% pre-load PUV temp (UTC->naive) per site tag
puvByTag=struct();
for s=1:numel(altDirs)
  recs={};
  for j=1:numel(altDirs(s).puv)
    dd=dir(fullfile(puvL2,altDirs(s).puv{j},'*_L2.mat'));
    for k=1:numel(dd)
      try P=load(fullfile(dd(k).folder,dd(k).name)); fn=fieldnames(P); L2=P.(fn{1});
        if ~isfield(L2,'time')||~isfield(L2,'Tmean'); continue; end
        tp=L2.time; tp.TimeZone=''; Tp=L2.Tmean(:); gp=isfinite(Tp); if nnz(gp)<50; continue; end
        [u,~,ii]=unique(dateshift(tp(gp),'start','hour')); r.t=u; r.T=accumarray(ii,Tp(gp),[],@mean); r.name=altDirs(s).puv{j};
        recs{end+1}=r; %#ok
      catch; end
    end
  end
  puvByTag.(altDirs(s).tag)=recs;
end

fprintf('\n%-46s %-4s %-22s %5s %4s %6s  %s\n','file','site','data range','lag','r','off','class');
fprintf('%s\n',repmat('-',1,108));
map={};
for s=1:numel(altDirs)
  ff=dir(fullfile(altDirs(s).dir,'*RANGELOGGER*.log'));
  recs=puvByTag.(altDirs(s).tag);
  for i=1:numel(ff)
    try TT=read_rangelogger_log(fullfile(ff(i).folder,ff(i).name)); catch; continue; end
    t=TT.Time; t.TimeZone=''; T=TT.Temperature_C; g=isfinite(T); t=t(g); T=T(g);
    if numel(t)<500; continue; end
    [uA,~,iA]=unique(dateshift(t,'start','hour')); mA=accumarray(iA,T,[],@mean);
    bestR=-inf;bestLag=NaN;bestPUV='(none)';
    for p=1:numel(recs)
      r=recs{p}; t0=max(min(uA),min(r.t)); t1=min(max(uA),max(r.t)); if t1-t0<hours(72); continue; end
      hg=(t0:hours(1):t1)'; Aa=interp1(uA,mA,hg,'linear',NaN); Bb=interp1(r.t,r.T,hg,'linear',NaN);
      v=isfinite(Aa)&isfinite(Bb); if nnz(v)<72; continue; end
      Aa=Aa-mean(Aa(v));Bb=Bb-mean(Bb(v));Aa(~v)=0;Bb(~v)=0;
      for L=-14:14
        B2=circshift(Bb,-L); if L>0,B2(end-L+1:end)=0; elseif L<0,B2(1:-L)=0; end
        m=(Aa~=0)&(B2~=0); if nnz(m)>60,rr=corr(Aa(m),B2(m)); if rr>bestR,bestR=rr;bestLag=L;bestPUV=recs{p}.name;end;end
      end
    end
    off=-bestLag;
    if isnan(bestLag), cls='NO PUV - infer';
    elseif bestR<0.6, cls=sprintf('LOW r (%.2f) - weak',bestR);
    elseif off>=7&&off<=8, cls='LOCAL';
    elseif off==0, cls='UTC';
    else, cls=sprintf('UNEXPECTED off=%d',off); end
    fprintf('%-46s %-4s %-10s..%-10s %+5d %4.2f %6s  %s\n', ff(i).name, altDirs(s).tag, ...
      datestr(t(1),'yyyy-mm-dd'), datestr(t(end),'yyyy-mm-dd'), bestLag, max(bestR,0), num2str(off), cls);
    map(end+1,:)={ff(i).name,altDirs(s).tag,datestr(t(1),'yyyy-mm-dd'),datestr(t(end),'yyyy-mm-dd'),bestLag,bestR,off,cls}; %#ok
  end
end
save('/tmp/perfile_clock_map.mat','map');
fprintf('\nSaved (%d files)\n',size(map,1));
