unit Horus.Shader.Raytracer;

interface

uses
  Mundus.Math,
  Mundus.Types,
  Mundus.Texture,
  Horus.SceneQuery;

type
  TTracerConstantInput = record
    Query: TSceneQuery;
    Light: TFloat3;
    DebugMap: TTexture;
  end;

  PTracerConstantInput = ^TTracerConstantInput;

  TTracerVertexInput = packed record
    UV: TFloat2;
    Normal: TFloat3;
  end;

  TTracerFragmentInput = packed record
    Position: TFloat3;
    Normal: TFloat3;
    UV: TFloat2;
  end;

  PTracerFragmentInput = ^TTracerFragmentInput;

const
  CTracerShader = 'Raytracer';

implementation

uses
  System.Math,
  Mundus.Shader,
  Mundus.Rasterizer.Helper,
  Mundus.Rasterizer.Types,
  Horus.Intersection;

procedure VertexShader(var AVertex: TFloat4; const [Ref] Constants: TTracerConstantInput; const [ref] AVInput: TTracerVertexInput; var AVOutput: TTracerFragmentInput);
begin
  AVOutput.Position := AVertex.XYZ;
  AVOutput.Normal := AVInput.Normal;
  if Assigned(Constants.DebugMap) then
  begin
    AVOutput.UV.U := AVInput.UV.U * Constants.DebugMap.Width;
    AVOutput.UV.V := AVInput.UV.V * Constants.DebugMap.Height;
  end;
  AVertex := Float4(AVInput.UV.U * 2 - 1, AVInput.UV.V * 2 - 1, 0, 1);
end;


function Intensity(const AIntensity, ADistance: Single): Single;
begin
  Result := AIntensity / (1 + (ADistance*ADistance));
end;

procedure FragmentShader(const Constants: PTracerConstantInput; const APixel: PRGB32; const PSInput: PTracerFragmentInput);
var
  LRayDirection, LOrigin: TFloat3;
  LShadowColor, LSample: TRGB32;
  LHitInfo: THitInfo;
  LLightDistance, LIntensity: Single;
  LValue: Byte;
const
  CLightColor: TRGB32 = (B: 255; G: 255; R: 255; A: 255);
  CShadowColor: TRGB32 = (B: 0; G: 0; R: 0; A: 255);
  CDebugShadowColor: TRGB32 = (B: 0; G: 255; R: 0; A: 255);
begin
  LShadowColor := CShadowColor;

  if Assigned(Constants.DebugMap) then
  begin
    Constants.DebugMap.SampleDot(PSInput.UV, @LSample);
    if (LSample.R > 0) and (LSample.B = 0) then
      LShadowColor := CDebugShadowColor
  end;

  LOrigin := PSInput.Position + PSInput.Normal*0.01;
  LLightDistance := (Constants.Light - LOrigin).Length;
  LRayDirection := (Constants.Light - LOrigin).Normalized;
  if Constants.Query.LineTrace(LOrigin, LRayDirection, LHitInfo) and (LHitInfo.Distance < LLightDistance) then
  begin
    APixel^ := LShadowColor;
  end
  else
  begin
    LIntensity := Intensity(2500000, LLightDistance);
    LValue := Trunc(LIntensity / (1 + LIntensity) * 255);
    LSample.B := LValue;
    LSample.G := LValue;
    LSample.R := LValue;
    LSample.A := 255;
    APixel^ := LSample;
  end;
end;

type TAttributes = TTracerFragmentInput;
const DepthTest = dtNone;
{$i Rasterizer.inc}

initialization
  TShaders.Register<TTracerConstantInput, TTracerVertexInput, TTracerFragmentInput>(CTracerShader, VertexShader, RasterizeTriangle);

end.
