unit ufillpoly2;

interface
  uses types, math,SysUtils;

procedure fillpoly(n : integer; const points: PPoint; PatternLine: TProc<{x0}integer,{x1}integer,{y}integer>);


implementation
 uses Generics.Collections;

type
  TSort<T> = record
     type
       TCompareFunction = function(const a,b : T) : integer;
     class procedure QuickSort(Values: TArray<T>; L,R : integer; compareFunc: TCompareFunction); static;
     class procedure Sort(Values: TArray<T>; compareFunc: TCompareFunction); static;
  end;

class procedure TSort<T>.Sort(Values: TArray<T>; compareFunc: TCompareFunction);
begin
  QuickSort(Values, 0, length(Values)-1, compareFunc);
end;

class procedure TSort<T>.QuickSort(Values: TArray<T>; L,R : integer; compareFunc: TCompareFunction);
var
  I, J: Integer;
  pivot, temp: T;
begin
  assert(assigned(compareFunc));
  if L < R then
  begin
    repeat
      if (R - L) = 1 then
      begin
        if CompareFunc(Values[L], Values[R]) > 0 then
        begin
          temp := Values[L];
          Values[L] := Values[R];
          Values[R] := temp;
        end;
        break;
      end;
      I := L;
      J := R;
      pivot := Values[L + (R - L) shr 1];
      repeat
        while CompareFunc(Values[I], pivot) < 0 do
          Inc(I);
        while CompareFunc(Values[J], pivot) > 0 do
          Dec(J);
        if I <= J then
        begin
          if I <> J then
          begin
            temp := Values[I];
            Values[I] := Values[J];
            Values[J] := temp;
          end;
          Inc(I);
          Dec(J);
        end;
      until I > J;
      if (J - L) > (R - I) then
      begin
        if I < R then
          QuickSort(Values, I, R, CompareFunc);
        R := J;
      end
      else
      begin
        if L < J then
          QuickSort(Values, L, J, CompareFunc);
        L := I;
      end;
    until L >= R;
  end;
end;


type
  TEDGE = record
     y_min, y_max : integer;
     m_inv, x_with_y_min : Single;
  end;

function edges_compare(const a,b : TEDGE) : integer;
begin
  result := a.y_min - b.y_min;
end;

function int_points_compare(const a,b : integer) : integer;
begin
  result := a - b;
end;


{$POINTERMATH ON}
procedure fillpoly(n : integer; const points: PPoint; PatternLine: TProc<integer,integer,integer>);
var
  edges: TArray<TEDGE>;
  edges_n:integer;
  int_points: TArray<integer>;
  int_points_n: integer;
  st,en :integer;
  mp : TDictionary<integer,integer>;
  i,y_tmp : integer;
  a,b : TPoint;
  y : integer;
  temp : TEDGE;
  tmp:   TPoint;
begin
	st := High(integer);
  en := Low(integer);
  mp := TDictionary<integer,integer>.Create;
  try
    setlength(edges,n);
    edges_n := 0;

    for i := 0 to n-1 do
    begin
      a := points[i];
      b := points[(i+1) mod n];
   { ignore if this is a horizontal edge}
      if a.y = b.y then continue;

      temp.y_min := min(a.y,b.y);
      temp.y_max := max(a.y,b.y);
      temp.x_with_y_min := ifthen(  (a.y < b.y) , a.x,  b.x  );
      temp.m_inv := (b.x - a.x) / (b.y - a.y);
      st := min(st, temp.y_min);
      en := max(en, temp.y_max);
      mp.AddOrSetValue(temp.y_min,1);
      edges[edges_n] := temp;
      inc(edges_n);
    end;
    n := edges_n;
    setLength(edges, n);
    TSort<TEDGE>.Sort(edges, edges_compare);
    for i := 0 to n-1 do
    begin
      if mp.TryGetValue(edges[i].y_max, y_tmp) then
         dec( edges[i].y_max);
    end;
    setLength(int_points, 16);
    for y := st to en do
    begin
       int_points_n := 0;
       i := 0;
       while i < n do
       begin
         if (y >= edges[i].y_min) and (y <= edges[i].y_max) then
         begin
            if int_points_n = length(int_points) then
               SetLength(int_points,int_points_n+16);
            int_points[int_points_n] := round(edges[i].x_with_y_min);
            inc(int_points_n);
            edges[i].x_with_y_min := edges[i].x_with_y_min + edges[i].m_inv;
            inc(i);
         end
         else
         if (y>edges[i].y_max) then
         begin
           dec(n);
           move(edges[i+1],edges[i],(n-i)*sizeof(edges[i]));
         end
         else
           inc(i);
       end;
       TSort<integer>.QuickSort(int_points,0,int_points_n-1, int_points_compare );
       i := 0;
       while i < int_points_n-1 do
       begin
         PatternLine(int_points[i], int_points[i+1], y);
         inc(i,2);
       end;
    end;

  finally
    mp.free;
  end;
end;


end.
