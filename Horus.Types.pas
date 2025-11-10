unit Horus.Types;

interface

uses
  Mundus.Math;

type
  TTriangle = record
    A, B, C: TFloat3;
    Normal: TFloat3;
    OriginDistance: Single;
  end;

  PTriangle = ^TTriangle;

implementation

end.
