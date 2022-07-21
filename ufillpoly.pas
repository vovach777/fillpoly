unit ufillpoly;

interface
  uses types, math,SysUtils;

{$POINTERMATH ON}

  type
  PointType = TPoint;


procedure fillpoly(numpoints : Word; const ptable: PPoint ; PatternLine: TProc<integer,integer,integer>; viewWidth, viewHeight:integer);


implementation


//  TProc<integer,integer,integer>
// Procedure PatternLine(x1, x2, y: integer);
// begin
// end;


//const
//   viewWidth = maxint;
//   ViewHeigh = maxint;

procedure fillpoly(numpoints : Word; const ptable: PPoint ; PatternLine: TProc<integer,integer,integer>; viewWidth, viewHeight:integer);

{ disable range check mode }
{$R-}
type
  pedge = ^tedge;
  tedge = packed record
    yMin, yMax, x, dX, dY, frac : Longint;
  end;

var
  nActive, nNextEdge : Longint;
  p0, p1 : pointtype;
  i, j, gap, x0, x1, y, nEdges : Longint;
  ET : Tarray<tedge>;
  GET, AET : Tarray<pedge>;
  t : pedge;

  LastPolygonStart : Longint;
  Closing, PrevClosing : Boolean;

begin
{ /********************************************************************
  * Add entries to the global edge table.  The global edge table has a
  * bucket for each scan line in the polygon. Each bucket contains all
  * the edges whose yMin == yScanline.  Each bucket contains the yMax,
  * the x coordinate at yMax, and the denominator of the slope (dX)
*/}
  setLength(et,   numpoints);//  getmem(et, sizeof(tedge) * numpoints);
  setlength(get,  numpoints);// getmem(get, sizeof(pedge) * numpoints);
  setlength(aet,  numpoints);//getmem(aet, sizeof(pedge) * numpoints);

 { check for getmem success }

  nEdges := 0;
  LastPolygonStart := 0;
  Closing := false;
  for i := 0 to (numpoints-1) do begin
    p0 := ptable[i];
    if (i+1) >= numpoints then p1 := ptable[0]
    else p1 := ptable[i+1];
    { save the 'closing' flag for the previous edge }
    PrevClosing := Closing;
    { check if the current edge is 'closing'. This means that it 'closes'
      the polygon by going back to the first point of the polygon.
      Also, 0-length edges are never considered 'closing'. }
    if ((p1.x <> ptable[i].x) or
        (p1.y <> ptable[i].y)) and
        (LastPolygonStart < i) and
       ((p1.x = ptable[LastPolygonStart].x) and
        (p1.y = ptable[LastPolygonStart].y)) then
    begin
      Closing := true;
      LastPolygonStart := i + 2;
    end
    else
      Closing := false;
    { skip current edge if the previous edge was 'closing'. This is TP7 compatible }
    if PrevClosing then
      continue;
   { draw the edges }
{    nickysn: moved after drawing the filled area
    Line(p0.x,p0.y,p1.x,p1.y);}
   { ignore if this is a horizontal edge}
    if (p0.y = p1.y) then continue;
   { swap ptable if necessary to ensure p0 contains yMin}
    if (p0.y > p1.y) then begin
      p0 := p1;
      p1 := ptable[i];
    end;
   { create the new edge }
    et[nEdges].ymin := p0.y;
    et[nEdges].ymax := p1.y;
    et[nEdges].x := p0.x;
    et[nEdges].dX := p1.x-p0.x;
    et[nEdges].dy := p1.y-p0.y;
    et[nEdges].frac := 0;
    get[nEdges] :=  @et[nEdges];
    inc(nEdges);
  end;
 { sort the GET on ymin }
  gap := 1;
  while (gap < nEdges) do gap := 3*gap+1;
  gap := gap div 3;
  while (gap > 0) do begin
    for i := gap to (nEdges-1) do begin
      j := i - gap;
      while (j >= 0) do begin
        if (GET[j].ymin <= GET[j+gap].yMin) then break;
        t := GET[j];
        GET[j] := GET[j+gap];
        GET[j+gap] := t;
        dec(j, gap);
      end;
    end;
    gap := gap div 3;
  end;
  { initialize the active edge table, and set y to first entering edge}
  nActive := 0;
  nNextEdge := 0;

  y := GET[nNextEdge].ymin;
  { Now process the edges using the scan line algorithm.  Active edges
  will be added to the Active Edge Table (AET), and inactive edges will
  be deleted.  X coordinates will be updated with incremental integer
  arithmetic using the slope (dY / dX) of the edges. }
  while (nNextEdge < nEdges) or (nActive <> 0) do begin
    {Move from the ET bucket y to the AET those edges whose yMin == y
    (entering edges) }
    while (nNextEdge < nEdges) and (GET[nNextEdge].ymin = y) do begin
      AET[nActive] := GET[nNextEdge];
      inc(nActive);
      inc(nNextEdge);
    end;
    { Remove from the AET those entries for which yMax == y (leaving
    edges) }
    i := 0;
    while (i < nActive) do begin
      if (AET[i].yMax = y) then begin
        dec(nActive);
        System.move(AET[i+1], AET[i], (nActive-i)*sizeof(pedge));
      end else
        inc(i);
    end;

    if (y >= 0) then begin
    {Now sort the AET on x.  Since the list is usually quite small,
    the sort is implemented as a simple non-recursive shell sort }

    gap := 1;
    while (gap < nActive) do gap := 3*gap+1;

    gap := gap div 3;
    while (gap > 0) do begin
      for i := gap to (nActive-1) do begin
        j := i - gap;
        while (j >= 0) do begin
          if (AET[j].x <= AET[j+gap].x) then break;
          t := AET[j];
          AET[j] := AET[j+gap];
          AET[j+gap] := t;
          dec(j, gap);
        end;
      end;
      gap := gap div 3;
    end;

    { Fill in desired pixels values on scan line y by using pairs of x
    coordinates from the AET }
    i := 0;
    while (i < (nActive - 1)) do begin
      x0 := AET[i].x;
      x1 := AET[i+1].x;
      {Left edge adjustment for positive fraction.  0 is interior. }
      if (AET[i].frac >= 0) then inc(x0);
      {Right edge adjustment for negative fraction.  0 is exterior. }
      if (AET[i+1].frac <= 0) then dec(x1);

      x0 := max(x0, 0);
      x1 := min(x1, viewWidth);
      { Draw interior spans}
      if (x1 >= x0) then begin
        PatternLine(x0, x1, y);
      end;

      inc(i, 2);
    end;

    end;

    { Update all the x coordinates.  Edges are scan converted using a
    modified midpoint algorithm (Bresenham's algorithm reduces to the
    midpoint algorithm for two dimensional lines) }
    for i := 0 to (nActive-1) do begin
      t := AET[i];
      { update the fraction by dX}
      inc(t.frac, t.dX);

      if (t.dX < 0) then
        while ( -(t.frac) >= t.dY) do begin
          inc(t.frac, t.dY);
          dec(t.x);
        end
      else
        while (t.frac >= t.dY) do begin
          dec(t.frac, t.dY);
          inc(t.x);
        end;
    end;
    inc(y);
    if (y >= ViewHeight) then break;
  end;

  { finally, draw the edges }
  LastPolygonStart := 0;
  Closing := false;
  for i := 0 to (numpoints-1) do begin
    p0 := ptable[i];
    if (i+1) >= numpoints then p1 := ptable[0]
    else p1 := ptable[i+1];
    { save the 'closing' flag for the previous edge }
    PrevClosing := Closing;
    { check if the current edge is 'closing'. This means that it 'closes'
      the polygon by going back to the first point of the polygon.
      Also, 0-length edges are never considered 'closing'. }
    if ((p1.x <> p0.x) or
        (p1.y <> p0.y)) and
        (LastPolygonStart < i) and
       ((p1.x = ptable[LastPolygonStart].x) and
        (p1.y = ptable[LastPolygonStart].y)) then
    begin
      Closing := true;
      LastPolygonStart := i + 2;
    end
    else
      Closing := false;
    { skip edge if the previous edge was 'closing'. This is TP7 compatible }
    if PrevClosing then
      continue;
   { draw the edges }
    //Line(p0.x,p0.y,p1.x,p1.y);
  end;

end;


end.
