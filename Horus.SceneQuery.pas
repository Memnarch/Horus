unit Horus.SceneQuery;

interface

uses
  Spring.Collections,
  Mundus.Mesh,
  Mundus.Math,
  Mundus.Types,
  Horus.Intersection,
  Horus.Types;

type
  THitInfo = record
    Position: TFloat3;
    Triangle: PTriangle;
    Distance: Single;
  end;

  TSceneQuery = class
  private
    FTriangles: TArray<TTriangle>;
  public
    procedure AddMesh(const AMesh: TMesh);
    function LineTrace(const ARayOrigin, ARayDirection: TFloat3; out AHitInfo: THitInfo): Boolean;
  end;

implementation

{ TSceneQuery }

procedure TSceneQuery.AddMesh(const AMesh: TMesh);
var
  LOffset: Integer;
  LTriangle: Mundus.Types.TTriangle;
  LRef: PTriangle;
begin
  LOffset := Length(FTriangles);
  SetLength(FTriangles, LOffset + Length(AMesh.Triangles));
  for LTriangle in AMesh.Triangles do
  begin
    LRef := @FTriangles[LOffset];
    LRef.A := AMesh.Vertices[LTriangle.VertexA];
    LRef.B := AMesh.Vertices[LTriangle.VertexB];
    LRef.C := AMesh.Vertices[LTriangle.VertexC];
    LRef.Normal := CalculateSurfaceNormal(LRef.A, LRef.B, LRef.C);
    LRef.OriginDistance := Dot(LRef.Normal, LRef.A);
    Inc(LOffset);
  end;
end;

function TSceneQuery.LineTrace(const ARayOrigin, ARayDirection: TFloat3; out AHitInfo: THitInfo): Boolean;
var
  i: Integer;
  LTriangle: PTriangle;
  LHitPos: TFloat3;
  LNewDistance: Single;
begin
  AHitInfo := Default(THitInfo);
  Result := False;
  for i := 0 to High(FTriangles) do
  begin
    LTriangle := @FTriangles[i];
    if RayTriangleIntersection(ARayOrigin, ARayDirection, LTriangle, LHitPos) then
    begin
      LNewDistance := (LHitPos - ARayOrigin).Length;
      //first hit?
      if not Result then
        Result := True
      //if not, check if further away and needs to be skipped
      else if LNewDistance > AHitInfo.Distance then
          Continue;

      AHitInfo.Position := LHitPos;
      AHitInfo.Triangle := LTriangle;
      AHitInfo.Distance := LNewDistance;
    end;
  end;
end;

end.
