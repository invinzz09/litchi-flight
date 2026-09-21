param(
  [Parameter(Mandatory=$true)][string]$Kml,
  [string]$Out,
  [double]$Alt = 100,
  [double]$Spacing = 66,
  [double]$CurvePct = 15,
  [double]$MaxSeg = 500,
  [int]$RowFrom = 1,
  [int]$RowTo = 0
)
$ErrorActionPreference = 'Stop'
[xml]$doc = Get-Content -LiteralPath $Kml -Encoding UTF8 -Raw
$ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
$ns.AddNamespace('k','http://www.opengis.net/kml/2.2')
$coordText = $doc.SelectSingleNode('//k:Polygon/k:outerBoundaryIs/k:LinearRing/k:coordinates',$ns).InnerText
$pts = @()
foreach ($tok in ($coordText -split '\s+')) {
  if ($tok.Trim() -eq '') { continue }
  $p = $tok.Split(',')
  $pts += ,@([double]::Parse($p[0],[Globalization.CultureInfo]::InvariantCulture),[double]::Parse($p[1],[Globalization.CultureInfo]::InvariantCulture))
}
# drop closing duplicate
if ($pts.Count -gt 1 -and $pts[0][0] -eq $pts[-1][0] -and $pts[0][1] -eq $pts[-1][1]) { $pts = $pts[0..($pts.Count-2)] }

# local metric projection
$lat0 = ($pts | ForEach-Object { $_[1] } | Measure-Object -Average).Average
$lon0 = ($pts | ForEach-Object { $_[0] } | Measure-Object -Average).Average
$R = 6371000.0
$kx = $R * [Math]::PI/180 * [Math]::Cos($lat0*[Math]::PI/180)
$ky = $R * [Math]::PI/180
$PM = @()
foreach ($p in $pts) { $px = $kx*($p[0]-$lon0); $py = $ky*($p[1]-$lat0); $PM += ,@($px, $py) }
$n = $PM.Count

# polygon area (ha) and perimeter
$area = 0
for ($i=0; $i -lt $n; $i++) { $j=($i+1)%$n; $area += $PM[$i][0]*$PM[$j][1] - $PM[$j][0]*$PM[$i][1] }
$area = [Math]::Abs($area)/2

# choose row direction: minimal perpendicular extent (fewest rows)
$bestA = 0; $bestW = [double]::MaxValue
for ($a=0; $a -lt 180; $a += 0.5) {
  $t = $a*[Math]::PI/180; $c=[Math]::Cos($t); $s=[Math]::Sin($t)
  $ymin=[double]::MaxValue; $ymax=-[double]::MaxValue
  foreach ($p in $PM) { $y = -$p[0]*$s + $p[1]*$c; if ($y -lt $ymin){$ymin=$y}; if ($y -gt $ymax){$ymax=$y} }
  $wid = $ymax-$ymin
  if ($wid -lt $bestW) { $bestW=$wid; $bestA=$a }
}
$t = $bestA*[Math]::PI/180; $c=[Math]::Cos($t); $s=[Math]::Sin($t)
# rotate polygon so rows are horizontal
$Q = @()
foreach ($p in $PM) { $qx = $p[0]*$c + $p[1]*$s; $qy = $p[1]*$c - $p[0]*$s; $Q += ,@($qx, $qy) }
$ymin = ($Q | ForEach-Object { $_[1] } | Measure-Object -Minimum).Minimum
$ymax = ($Q | ForEach-Object { $_[1] } | Measure-Object -Maximum).Maximum
$H = $ymax-$ymin
$rows = [Math]::Max(1,[Math]::Ceiling($H/$Spacing))
$y0 = $ymin + ($H - ($rows-1)*$Spacing)/2

$path = @()   # list of @(x,y) in rotated frame
if ($RowTo -le 0) { $RowTo = $rows }
for ($r=$RowFrom-1; $r -lt $RowTo; $r++) {
  $y = $y0 + $r*$Spacing
  $xs = @()
  for ($i=0; $i -lt $n; $i++) {
    $j=($i+1)%$n; $a1=$Q[$i]; $a2=$Q[$j]
    if (($a1[1] -le $y -and $a2[1] -gt $y) -or ($a2[1] -le $y -and $a1[1] -gt $y)) {
      $xs += $a1[0] + ($y-$a1[1])*($a2[0]-$a1[0])/($a2[1]-$a1[1])
    }
  }
  if ($xs.Count -lt 2) { continue }
  $xa = ($xs | Measure-Object -Minimum).Minimum; $xb = ($xs | Measure-Object -Maximum).Maximum
  if ($r % 2 -eq 1) { $tmp=$xa; $xa=$xb; $xb=$tmp }
  $len = [Math]::Abs($xb-$xa)
  $segs = [Math]::Max(1,[Math]::Ceiling($len/$MaxSeg))
  for ($k=0; $k -le $segs; $k++) { $xk = $xa + ($xb-$xa)*$k/$segs; $path += ,@($xk, $y) }
}

# back to lat/lon
$W = @()
foreach ($pt in $path) {
  $x = $pt[0]*$c - $pt[1]*$s; $y = $pt[0]*$s + $pt[1]*$c
  $la = $lat0 + $y/$ky; $lo = $lon0 + $x/$kx; $W += ,@($la, $lo, $x, $y)
}
$m = $W.Count
$total = 0
$legs = @()
for ($i=0; $i -lt $m-1; $i++) { $d=[Math]::Sqrt(($W[$i+1][2]-$W[$i][2])*($W[$i+1][2]-$W[$i][2]) + ($W[$i+1][3]-$W[$i][3])*($W[$i+1][3]-$W[$i][3])); $legs += $d; $total += $d }

$inv = [Globalization.CultureInfo]::InvariantCulture
$lines = @('latitude,longitude,altitude(m),heading(deg),curvesize(m),rotationdir,gimbalmode,gimbalpitchangle,actiontype1,actionparam1,altitudemode,speed(m/s),poi_latitude,poi_longitude,poi_altitude(m),poi_altitudemode,photo_timeinterval,photo_distinterval')
for ($i=0; $i -lt $m; $i++) {
  $curve = 0
  if ($i -gt 0 -and $i -lt $m-1) { $curve = [Math]::Round([Math]::Min($legs[$i-1]/2,$legs[$i]/2)*$CurvePct/100,1) }
  $hd = 0
  if ($i -lt $m-1) { $hd = [Math]::Round((([Math]::Atan2($W[$i+1][2]-$W[$i][2], $W[$i+1][3]-$W[$i][3])*180/[Math]::PI)+360)%360) } elseif ($m -gt 1) { $hd = [Math]::Round((([Math]::Atan2($W[$i][2]-$W[$i-1][2], $W[$i][3]-$W[$i-1][3])*180/[Math]::PI)+360)%360) }
  $lines += ('{0},{1},{2},{3},{4},0,0,0,-1,0,1,0,0,0,0,0,-1,-1' -f $W[$i][0].ToString('F6',$inv), $W[$i][1].ToString('F6',$inv), $Alt.ToString($inv), $hd, $curve.ToString($inv))
}
if (-not $Out) { $Out = [IO.Path]::ChangeExtension($Kml,'.csv') }
[IO.File]::WriteAllLines($Out, $lines, (New-Object System.Text.UTF8Encoding($false)))
"file: $Out"
"area: {0:F2} ha, rows: {1}, direction: {2} deg, waypoints: {3}" -f ($area/10000), $rows, $bestA, $m
"length: {0:F0} m, est. time at 8.3 m/s: {1:F1} min" -f $total, ($total/8.3/60)
