# ============================================================================
# 04_report.R  —  builds the LPI methodology / results HTML report.
# Inputs : outputs/models.rds, outputs/lpi_composite.rds, outputs/lei_annual.rds,
#          outputs/{grp_*.png via groupFig}, outputs/lpi_weights.png, assets/report.css
# Output : docs/lpi_structure_report.html   (self-contained; also the Artifact source)
# Run from: model/model_LPI/  (after 02 and 03)
# ============================================================================
SC<-"outputs"                                   # base dir for chart PNGs (in/out)
suppressMessages(library(base64enc))
M<-readRDS("outputs/models.rds")
LP<-readRDS("outputs/lpi_composite.rds"); W<-LP$W; r25<-LP$res[["2025"]]
d2<-readRDS("outputs/lei_annual.rds"); agg<-d2$agg
# --- December 2025 (latest month) composite: 2025 structure + weights, Dec-2025 pressure ---
suppressMessages(library(readxl))
.leim<-readxl::read_excel("../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx",sheet="LEI Per Provinsi")
.pvc<-names(r25$s100); .sel<-.leim$Tahun==2025 & .leim$Bulan==12
declei<-setNames(.leim$Indeks_LEI_Labour[.sel],.leim$Provinsi[.sel])[.pvc]
tekdec<-setNames(100*(declei-min(declei))/(max(declei)-min(declei)),.pvc)          # Dec-2025 pressure 0-100
lpidec<-setNames(as.numeric(r25$w[1]*r25$pk[.pvc]+r25$w[2]*r25$st[.pvc]+r25$w[3]*tekdec),.pvc) # Dec-2025 LPI
M$L9$name<-"Indeks Kerentanan Pasar Kerja"; M$E5$name<-"Indeks Kerentanan Struktural Ekonomi"
H<-character(0); add<-function(...)H<<-c(H,paste0(...))
fmt<-function(x,d=3)formatC(x,format="f",digits=d)
b64<-function(f)paste0("data:image/png;base64,",base64encode(f))
kbadge<-function(k)if(is.na(k))"" else if(k<0.5)"v-xl" else if(k<0.6)"v-lo" else if(k>=0.7)"v-hi" else ""
condc<-function(c)if(c>100)"v-xl" else if(c>30)"v-lo" else "v-hi"
vcls<-function(v){a<-abs(v);if(is.na(v))"" else if(a>=.5)"v-hi" else if(a>=.4)"v-md" else if(a>=.3)"v-lo" else "v-xl"}
heatv<-function(v){a<-abs(v);if(is.na(v)||a>=.999)"" else if(a>=.8)"v-hi" else if(a>=.6)"v-md" else if(a>=.4)"v-lo" else "v-xl"}
sr_c<-function(v)if(is.na(v))"" else if(v>=.5)"v-hi" else if(v>=.35)"v-md" else if(v>=.2)"v-lo" else "v-xl"
GCOL<-c("#b0402f","#d0863f","#5f97a8","#2b4a6f")   # G1 highest (red) -> G4 lowest (blue)
ys<-as.character(2022:2025)
metricsT<-function(E){add("<div class='tbl-wrap'><table class='data'><thead><tr><th>Year</th><th>N</th><th>KMO</th><th>PC1%</th><th>Factors</th><th>Cond#</th><th class='grp'>Spear&nbsp;rate</th><th>Spear&nbsp;tot</th></tr></thead><tbody>")
 for(yr in ys){r<-E[[yr]];add(sprintf("<tr><td class='sp'>%s</td><td>%d</td><td class='%s'>%s</td><td>%.0f%%</td><td class='%s'>%d</td><td class='%s'>%.0f</td><td class='%s grp'>%s</td><td class='%s'>%s</td></tr>",
   yr,r$n,kbadge(r$kmo),fmt(r$kmo),100*r$pc1,if(sum(r$eig>1)>1)"v-lo" else "",sum(r$eig>1),condc(r$cond),r$cond,sr_c(r$sr),fmt(r$sr),vcls(r$st),fmt(r$st)))}
 add("</tbody></table></div>")}
loadT<-function(mod){r<-mod$E[["2025"]];lab<-mod$lab;names(lab)<-mod$vars;ld<-r$load;ct<-100*ld^2/sum(ld^2)
 add("<div class='tbl-wrap'><table class='data load'><thead><tr><th>Variable (2025)</th><th class='grp'>PC1 loading</th><th class='cyr'>contrib&nbsp;%</th><th>MSA</th></tr></thead><tbody>")
 for(v in names(sort(ld))){add(sprintf("<tr><td class='sp'>%s</td><td class='%s grp'>%+.3f</td><td class='contrib'>%.1f</td><td class='%s'>%.2f</td></tr>",lab[v],if(ld[v]>=0)"pos" else "neg",ld[v],ct[v],if(r$msa[v]<0.5)"v-xl" else "",r$msa[v]))}
 add("</tbody></table></div>")}
cormatT<-function(C){add("<div class='tbl-wrap'><table class='data'><thead><tr><th>r (2025)</th>",paste0("<th>",colnames(C),"</th>",collapse=""),"</tr></thead><tbody>")
 for(i in 1:nrow(C)){add("<tr><td class='sp'>",rownames(C)[i],"</td>");for(j in 1:ncol(C)){v<-C[i,j];add(sprintf("<td class='%s'>%+.2f</td>",if(i==j)"muted" else heatv(v),v))};add("</tr>")};add("</tbody></table></div>")}
## ---- quartile (equal-count) grouped ranked chart; group legend rendered in HTML ----
groupFig<-function(scores,gnames,title,file,cap){
 s<-sort(scores,decreasing=FALSE);n<-length(s)
 rk<-rank(-s,ties.method="first");g<-ceiling(rk/(n/4));g[g>4]<-4
 provcol<-GCOL[g];cnt<-as.integer(table(factor(g,levels=1:4)))
 leglab<-sprintf("%s  (n=%d)",gnames,cnt)
 nc<-if(max(nchar(gnames))>26) 1L else 2L                 # long names -> stack vertically
 lh<-if(nc==1) 210 else 130                               # legend panel height (px)
 mh<-max(1000,90+n*32)
 png(file,width=1360,height=mh+lh,res=150)
 layout(matrix(c(1,2),2,1),heights=c(mh,lh))              # plot on top, legend baked in below
 par(mar=c(4,9.5,3,1.5),mgp=c(2.3,.6,0))
 bp<-barplot(s,horiz=TRUE,las=1,col=provcol,border=NA,names.arg=names(s),cex.names=.52,xlab="Skor indeks (0-100)",main=title,col.main="#14181f",cex.main=1,xlim=c(0,107))
 text(s,bp,labels=sprintf("%.1f",s),pos=4,offset=0.3,cex=.5,col="#14181f",font=2,xpd=NA)
 par(mar=c(0.2,2,1.4,1.5));plot.new()
 legend("top",legend=leglab,fill=GCOL,border="white",bty="n",ncol=nc,cex=.72,
        text.col="#14181f",title="Kelompok  (skor tertinggi → terendah)",title.adj=0,
        title.col="#14181f",x.intersp=.6,y.intersp=1.15)
 dev.off()
 add("<div class='fig'><img src='",b64(file),"' alt='grouped distribution'><p class='cap'>",cap,"</p></div>")}
renderModel<-function(key,id,note,gnames){mod<-M[[key]];r<-mod$E[["2025"]]
 add(sprintf("<h3 id='%s' class='mt'><span class='idxtag'>%s</span></h3>",id,mod$name))
 add("<p class='lead' style='margin-bottom:8px'>",mod$desc,". Oriented so <i>",mod$lab[which(mod$vars==mod$anchor)],"</i> loads positive.</p>")
 metricsT(mod$E); loadT(mod)
 add("<h4 class='mt' style='margin-top:12px'>Variable correlation matrix (2025, Pearson)</h4>"); cormatT(mod$cor)
 add("<h4 class='mt'>Provincial groups (2025) &mdash; 4 equal-count tiers</h4>")
 groupFig(r$s100,gnames,mod$name,file.path(SC,paste0("grp_",key,".png")),
   "Provinces split into <b>4 groups of equal size</b> (quartiles by rank); group 1 = highest score (top). Colours: red = highest tier &rarr; blue = lowest.")
 add("<p class='note'>",note,"</p>")}
## group-name sets
gPK<-c("Pasar Kerja Berbasis Formal","Pasar Kerja dengan Formalisasi Berkembang","Pasar Kerja dalam Transisi","Pasar Kerja Informal Berbasis Pertanian")
gST<-c("Ekonomi Industri Berorientasi Perdagangan","Ekonomi dengan Basis Industri Berkembang","Ekonomi Terdiversifikasi","Ekonomi Domestik Berbasis Pertanian")
gTM<-c("Tekanan Sangat Tinggi","Tekanan Tinggi","Tekanan Sedang","Tekanan Rendah")
gLPI<-c("Risiko Sangat Tinggi","Risiko Tinggi","Risiko Sedang","Risiko Rendah")

## ===== HEAD =====
add(paste0("<style>\n",paste(readLines("assets/report.css"),collapse="\n"),"\n</style>"))
add("<style>.glegend{display:flex;flex-wrap:wrap;gap:7px 20px;margin:8px 4px 2px;font-size:12.5px;color:var(--ink2)}",
 ".gchip{display:inline-flex;align-items:center;gap:7px}",
 ".gsw{width:13px;height:13px;border-radius:3px;display:inline-block;flex:0 0 auto}",
 ".gn{color:var(--muted);font-size:11.5px}</style>")
add("<header class='hd'><p class='kicker'>Dewan Ekonomi Nasional · PHK Early-Warning Dashboard</p><h1>Layoff Pressure Index (LPI) — Provincial Composite</h1>",
 "<p class='sub'>The LPI combines three provincial indices — <b>Indeks Kerentanan Pasar Kerja</b> (labour-market vulnerability), <b>Indeks Kerentanan Struktural Ekonomi</b> (economic-structure vulnerability), and <b>Indeks Tekanan Makroekonomi</b> (macroeconomic pressure) — into one early-warning score per province. Each vulnerability index is a PCA index (2022–2025, 38 provinces); the three are combined with the <b>OECD factor-analysis weighting method</b>. Recorded PHK is used <b>only to validate</b>, never as an input.</p></header>")
add("<nav class='sidenav'><p class='snav-title'>Navigasi</p>",
 "<a class='sec' href='#s1'>1 · Kerentanan Pasar Kerja</a>",
 "<a class='sec' href='#s2'>2 · Kerentanan Struktural Ekonomi</a>",
 "<a class='sec' href='#s3'>3 · Tekanan Makroekonomi</a>",
 "<a class='sec' href='#s4'>4 · Composite LPI</a>",
 "<a class='sub' href='#s4a'>Methodology</a><a class='sub' href='#s4b'>Weights</a><a class='sub' href='#s4c'>Composite score</a></nav>")
add("<section><div class='card'><h3>How to read the two vulnerability indices</h3><p class='cardp'><b>KMO</b> (sampling adequacy) should be &ge;0.6 — green healthy, red &lt;0.5 unacceptable. <b>Factors</b> = eigenvalues &gt;1 (Kaiser); <b>1</b> = a single clean dimension. <b>Cond#</b> = condition number; &gt;100 (red) = severe multicollinearity. <b>Spear rate</b> = rank correlation with PHK per 100k formal workers; <b>Spear tot</b> uses total PHK. Provincial charts group the 38 provinces into <b>4 equal-count tiers</b> (quartiles).</p></div></section>")

## ===== SECTION 1 =====
add("<section id='s1'><h2>1 · Indeks Kerentanan Pasar Kerja</h2>")
add("<p class='lead'>How formal, full-time and industrial a province's labour market is — i.e. <i>who holds the kind of recordable formal jobs that PHK actually strikes</i>. A five-variable formal-vs-informal factor.</p>")
renderModel("L9","s1x","<b>A single clean formal-vs-informal factor.</b> Formal share and full-time share move almost together (+0.90); underemployment loads <b>negative</b> — hidden slack marks the informal/agrarian end that formal PHK bypasses. Manufacturing labour share is the least-redundant marker (only +0.36 with formal). Clean in 2022&ndash;2024 (KMO 0.65&ndash;0.78); in 2025 one extreme province (Papua Pegunungan) softens it to KMO 0.65. Validation against PHK ~0.40&ndash;0.42.",gPK)
add("</section>")

## ===== SECTION 2 =====
add("<section id='s2'><h2>2 · Indeks Kerentanan Struktural Ekonomi</h2>")
add("<p class='lead'>How trade-integrated and industrial the province's economy is versus domestic and agrarian — i.e. <i>which economies are structurally layoff-prone</i>. Five expenditure/sector shares of PDRB, after removing the collinear reference and inert variables.</p>")
renderModel("E5","s2x","<b>A valid single factor.</b> Dropping the two compositional reference categories (consumption, services) and the inert own-axis variable (mining) yields <b>KMO 0.70, one Kaiser factor, condition # 13</b>, every variable MSA &ge; 0.66. PC1 reads as <b>trade-integrated &amp; industrial &harr; domestic &amp; agrarian</b> (export / import / manufacturing positive; agriculture / government negative). Strongest PHK validator of the two vulnerability indices — Spear-rate <b>0.66</b> in 2025.",gST)
add("</section>")

## ===== SECTION 3 : TEKANAN =====
add("<section id='s3'><h2>3 · Indeks Tekanan Makroekonomi</h2>")
add("<p class='lead'>The third index is an early-warning gauge — the <b>LEI</b> (<code>Indeks_LEI_Labour</code>, from <code>Komposit_LEI_Ketenagakerjaan</code>). Where the two vulnerability indices describe <i>who is exposed</i>, this index is a <i>timing / pressure</i> signal that moves month to month with building stress. Higher = more layoff risk.</p>")
add("<div class='grid2'>")
add("<div class='card'><h3>What it is</h3><p class='cardp'>A monthly, province-level composite index — 38 provinces &times; 48 months (2022&ndash;2025). It captures <b>building layoff pressure over time</b>, a dimension the static structural indices cannot.</p></div>")
add("<div class='card'><h3>How it enters the LPI</h3><p class='cardp'>Each month the LEI is <b>min-max&rsquo;d across provinces</b> (the same standardisation as the two structural indices) &rarr; a 0&ndash;100 pressure score, combined with the structural indices as an <b>independent third dimension</b>. The map below uses the <b>latest month, December 2025</b>.</p></div>")
add("</div>")
add("<h4 class='mt'>Provincial groups &mdash; December 2025 (latest month), 4 equal-count tiers</h4>")
groupFig(tekdec,gTM,"Indeks Tekanan Makroekonomi (Des 2025)",file.path(SC,"grp_TM.png"),
  "December 2025 LEI, min-max across provinces; provinces in <b>4 equal-count tiers</b>. Red = highest pressure &rarr; blue = lowest.")
add("</section>")

## ===== SECTION 4 : COMPOSITE LPI =====
add("<section id='s4'><h2>4 · Indeks Tekanan PHK (Composite LPI)</h2>")
add("<p class='lead'>The three indices are combined into one <b>Layoff Pressure Index</b> per province. The weights are <b>not assumed or set equal</b> &mdash; they are derived from the data with the <b>OECD/JRC factor-analysis weighting method</b> for composite indicators (Nicoletti et al., 2000; OECD-JRC <i>Handbook on Constructing Composite Indicators</i>, 2008, &sect;6.1), estimated separately each year.</p>")
add("<div class='card'><h3>Two-stage (nested) architecture</h3><p class='cardp'><b>Stage 1</b> &mdash; each index is already a first-layer PCA index (Sections 1&ndash;2) plus the LEI (Section 3). <b>Stage 2</b> &mdash; a second PCA over the three index scores produces the weights, which aggregate them into the LPI. Recorded PHK is used <b>only to validate</b>, never to estimate the weights.</p></div>")

add("<h3 id='s4a' class='mt'>Step-by-step methodology (Stage-2 weighting)</h3>")
add("<ol class='steps'>",
 "<li><b>Standardise</b> the three index scores to mean 0, SD 1 within each year (common scale &mdash; an OECD requirement).</li>",
 "<li><b>Correlation matrix</b> of the three standardised indices.</li>",
 "<li><b>Extract dimensions</b> by principal-component analysis; read the <b>eigenvalues</b> (each = &ldquo;how many indices&rsquo; worth of information&rdquo; a dimension carries; they sum to 3).</li>",
 "<li><b>Retain dimensions.</b> Keep those with eigenvalue &gt; 1 <i>or &ldquo;close to 1&rdquo;</i> (the OECD example retained a 0.9 dimension), each explaining &gt; 10% and together &gt; 60%. Here that is <b>m = 2</b> every year: a <i>Kerentanan (vulnerability)</i> dimension (Kerentanan Pasar Kerja + Kerentanan Struktural Ekonomi) and a <i>Tekanan (pressure)</i> dimension (Tekanan Makroekonomi); the residual third dimension is dropped.</li>",
 "<li><b>Varimax rotation</b> of the two retained dimensions &rarr; &ldquo;clean structure&rdquo;, so each index loads mainly on one dimension.</li>",
 "<li><b>Build the weights:</b> weight(index) = (its squared loading share <i>within</i> its dimension) &times; (that dimension&rsquo;s share of the retained information), then rescale so the three sum to 100%.</li>",
 "</ol>")
add("<p class='note'><b>The key judgement</b> is retaining the second dimension (eigenvalue ~0.9&ndash;1.0). If only one were kept, the whole index would collapse to the &ldquo;kerentanan&rdquo; story and Tekanan Makroekonomi would be near-ignored. Keeping it &mdash; justified by the OECD&rsquo;s own criteria and worked example &mdash; is what gives the pressure early-warning a real, stable weight. Method family: <i>statistical / PCA-FA weighting</i>.</p>")

add("<h3 id='s4b' class='mt'>Resulting weights (per year)</h3>")
add("<div class='tbl-wrap'><table class='data'><thead><tr><th>Year</th><th>N</th><th class='grp'>Kerentanan Pasar Kerja</th><th>Kerentanan Struktural Ekonomi</th><th>Tekanan Makroekonomi</th><th class='grp'>Dim. Kerentanan</th><th>Dim. Tekanan</th></tr></thead><tbody>")
for(i in 1:nrow(W))add(sprintf("<tr><td class='sp'>%d</td><td>%d</td><td class='grp'>%.1f%%</td><td>%.1f%%</td><td class='v-md'>%.1f%%</td><td class='grp'>%.1f%%</td><td>%.1f%%</td></tr>",
  W$year[i],W$N[i],W$Labour[i],W$Econ[i],W$Pressure[i],W$F1_share[i],W$F2_share[i]))
add(sprintf("<tr class='pref'><td class='sp'>mean</td><td></td><td class='grp'>%.1f%%</td><td>%.1f%%</td><td>%.1f%%</td><td class='grp'></td><td></td></tr>",mean(W$Labour),mean(W$Econ),mean(W$Pressure)))
add("</tbody></table></div>")
add("<div class='fig'><img src='",b64(file.path(SC,"lpi_weights.png")),"' alt='LPI weights by year'><p class='cap'>OECD factor-analysis weights, 2022&ndash;2025. Roughly balanced (~30 / 32 / 38), with Tekanan Makroekonomi slightly highest and stable across years.</p></div>")

add("<h4 class='mt'>Worked example — 2025 (N = ",r25$N,")</h4>")
add("<p class='note' style='margin-top:4px'>Eigenvalues ",paste(sprintf("%.2f",r25$eig),collapse=", ")," &rarr; variance ",paste(sprintf("%.0f%%",100*r25$eig/sum(r25$eig)),collapse=", "),
 "; the first two hold ",sprintf("%.0f%%",100*sum(r25$eig[1:2])/sum(r25$eig))," &rarr; keep 2. Rotated loadings, then the weight build-up:</p>")
labs<-c(Labour="Kerentanan Pasar Kerja",Econ="Kerentanan Struktural Ekonomi",Pressure="Tekanan Makroekonomi")
add("<div class='tbl-wrap'><table class='data load'><thead><tr><th>Index</th><th class='grp'>load: Kerentanan</th><th>load: Tekanan</th><th>assigned</th><th>within-share</th><th>dim share</th><th>weight</th></tr></thead><tbody>")
for(k in c("Labour","Econ","Pressure")){f<-r25$assign[k];add(sprintf("<tr><td class='sp'>%s</td><td class='grp'>%+.3f</td><td>%+.3f</td><td>%s</td><td>%.3f</td><td>%.3f</td><td class='v-md'>%.1f%%</td></tr>",
  labs[k],r25$Lr[k,1],r25$Lr[k,2],c("Kerentanan","Tekanan")[f],r25$within[k,f],r25$fshare[f],100*r25$w[k]))}
add("</tbody></table></div>")

add("<h3 id='s4c' class='mt'>The composite LPI score &mdash; December 2025</h3>")
add("<p class='lead' style='margin-bottom:8px'>Each province&rsquo;s LPI = the <b>weighted sum of its three 0&ndash;100 index scores</b> (each already normalised within its own index), using the <b>2025 weights above</b>. The two structural indices are the 2025 values; the pressure index is the <b>latest month (December 2025)</b>. Because the three inputs are 0&ndash;100 and the weights sum to 100%, the LPI is itself on a 0&ndash;100 scale. Higher = more layoff pressure.</p>")
add("<h4 class='mt'>Provincial groups &mdash; December 2025 (latest month), 4 equal-count tiers</h4>")
groupFig(lpidec,gLPI,"Composite LPI (Des 2025)",file.path(SC,"grp_LPI.png"),
  "Overall LPI &mdash; <b>December 2025</b> (2025 structure &amp; weights, December pressure); provinces in <b>4 equal-count risk tiers</b>. Red = highest overall layoff pressure &rarr; blue = lowest.")
add("<p class='note'>This map is the <b>latest month (December 2025)</b>: it combines the 2025 structural &amp; labour-market vulnerability with December&rsquo;s macro pressure. Each month re-ranks the provinces as pressure moves; the structural indices and weights are refreshed once a year. An early-warning map, not a forecast. Validated against recorded PHK (never an input): the two vulnerability indices validate 0.40&ndash;0.66; Tekanan Makroekonomi adds an independent signal.</p>")
add("</section>")
dir.create("docs",showWarnings=FALSE)
writeLines(H,"docs/lpi_structure_report.html");cat("written",length(H),"chunks -> docs/lpi_structure_report.html\n")
